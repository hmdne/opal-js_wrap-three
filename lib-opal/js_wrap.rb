# helpers: native, defineProperty
# backtick_javascript: true

`var inspect_stack = []`

# JSWrap is basically a Native v2. It has the same aims and goals. It should
# be interoperable with Native, ie. both modules can coexist.

# TODO: DSL methods:
#  - js_method
#    - (
#        how about something like: js_method :set_timeout => [:$block, :timeout]
#        which would allow us also to call it using any of the following:
#        `Window.set_timeout(timeout: 123) { p "Hello!" }`
#        `Window.set_timeout(123) { p "Hello!" }`
#        `Window.set_timeout(-> { p "Hello" }, 123)`
#      )
# TODO: support for restricted values
# TODO: to_js

module JSWrap
  module WrapperClassMethods
    # By default, we will transfer calls and properties like
    # "my_method" into "myMethod". Since, unlike with Native, we
    # inherit from Object, not BasicObject, some call names may
    # conflict, but we can use names like "class_" instead of
    # "class". This setting allows us to disable this behavior.
    attr_accessor :js_raw_naming

    # The default behavior when dispatching to a function is to
    # call it and return a result.
    attr_accessor :js_function_wrap

    # The default behavior for things based on ObjectWrapper is to
    # automatically wrap even the regular Arrays, so that we may
    # correctly wrap all members.
    #
    # The default behavior for things based on Wrapper is to never
    # wrap the regular Arrays, only Array-like things. It is the
    # responsibility of the programmer to provide a good interface.
    #
    # This property allows you to change the default behavior.
    attr_accessor :js_array_wrap

    def js_attr_reader(*vars)
      vars.each do |var|
        define_method(var) { js_property(var) }
      end
      vars.length > 1 ? vars : vars.first
    end

    def js_attr_writer(*vars)
      vars.each do |var|
        define_method(:"#{var}=") { |val| js_property_set(var, val) }
      end
      vars.length > 1 ? vars : vars.first
    end

    def js_attr_accessor(*vars)
      Array(js_attr_reader(*vars)) + Array(js_attr_writer(*vars))
    end

    def js_method(*vars)
      vars.each do |var|
        define_method(var) do |*args,&block|
          args << block if block_given?
          js_property(var, args: args)
        end
      end
      vars.length > 1 ? vars : vars.first
    end

    def js_export_class(classname = name)
      `Opal.global[name] = self`
    end

    alias js_export_module js_export_class

    # Example:
    #
    # module Blobulizer
    #   include JSWrap::Wrapper
    #   js_export_module
    #
    #   js_export def self.extended_blobulize(thing)
    #     Blobulizer::Processor.new(thing).extended_blobulize
    #   end
    # end
    #
    # JS:
    # Blobulizer.extendedBlobulize({hello: "world"})
    def js_export(*args)
      args = Array(args.first) if args.length == 1

      args.each do |i|
        `self[#{js_property_name_rb2js(i)}] = #{JSWrap.unwrap_proc(`method(i).to_proc`, self)}`
      end
    end

    def wrap(object, parent = nil)
      obj = allocate
      obj.initialize_wrapped(object, parent)
      obj
    end

    def js_class(js_constructor)
      js_constructor = JSWrap.unwrap(js_constructor, self)
      @native = js_constructor
      JSWrap.register_wrapping(self, js_constructor)
    end

    # Also includes RawClassWrapper, but we don't have that yet.
  end

  module Wrapper
    def self.included(klass)
      klass.extend(WrapperClassMethods)
      super
    end

    attr_accessor :native

    def initialize_wrapped(object, parent = nil)
      %x{
        try {
          $defineProperty(object, '$$js_wrap', self)
        }
        catch(e) {}
      }
      @native_parent = parent if parent
      @native = object
    end

    def initialize(*args, &block)
      raise NotImplementedError, 'See [doc:JSWrap::Wrapper#initialize]' unless `#{self.class}.native`

      args << block if block_given?
      args = JSWrap.unwrap_ary(args, self)
      obj = `new (self.$$class.native.bind.apply(self.$$class.native, [null].concat(args)))`
      initialize_wrapped(obj)
    end

    # @private
    def js_property_name_rb2js(name, raw: nil)
      raw = self.js_function_wrap if raw.nil?
      if raw || name.start_with?(/[_A-Z]/)
        name
      else
        name.gsub(/_(.?)/) { Regexp.last_match(1).upcase }
      end
    end

    # @private
    def js_property_name_js2rb(name, raw: nil)
      raw = self.js_function_wrap if raw.nil?
      if raw || name.start_with?(/[_A-Z]/)
        name
      else
        name.gsub(/([A-Z])/) { '_' + Regexp.last_match(1).downcase }
      end
    end

    def js_properties(not_just_own = true, raw: nil)
      %x{
        var out = [];
        for (var name in self.native) {
          if (!not_just_own || self.native.hasOwnProperty(name)) {
            #{`out` << js_property_name_js2rb(`name`, raw: raw)}
          }
        }
        return out;
      }
    end

    def js_property?(name, raw: nil)
      %x{
        return #{js_property_name_rb2js(name, raw: raw)} in self.native
      }
    end

    # Returns a wrapped property. If args are nil, functions are
    # always returned verbatim.
    def js_property(name, raw: nil, args: nil)
      JSWrap(`self.native[#{
               js_property_name_rb2js(name, raw: raw)
             }]`,
        self, args, name: name
      )
    end

    def js_property_set(name, value, raw: nil)
      `self.native[#{
        js_property_name_rb2js(name, raw: raw)
      }] = #{JSWrap.unwrap(value, self)}`
    end

    def js_raw_naming
      @js_raw_naming.nil? ? self.class.js_raw_naming : @js_raw_naming
    end

    def js_function_wrap
      @js_function_wrap.nil? ? self.class.js_function_wrap : @js_function_wrap
    end

    def js_array_wrap
      @js_array_wrap.nil? ? self.class.js_array_wrap : @js_array_wrap
    end

    def to_js
      @native
    end

    alias to_n to_js
  end

  module ObjectWrapper
    include Enumerable
    include Wrapper

    alias [] js_property

    def []=(name, kwargs = {}, value)
      js_property_set(name, value, **kwargs)
    end

    alias keys js_properties
    alias has? js_property
    alias include? js_property

    def values
      to_h.values
    end

    def each(&block)
      return enum_for(:each) { length } unless block_given?

      %x{
        for (var name in self.native) {
          Opal.yieldX(block, [
            #{js_property_name_js2rb `name`},
            #{JSWrap(`self.native[name]`, self)}
          ]);
        }
      }
      self
    end

    def inspect
      if `inspect_stack`.include?(__id__)
        inside = '...'
      else
        inside = to_h.inspect
        `inspect_stack` << __id__
        pushed = true
      end
      klass = `Object.prototype.toString.apply(self.native)`
      klass =~ /^\[object (.*?)\]$/
      "#<#{self.class.name} #{Regexp.last_match(1) || klass} #{inside}>"
    ensure
      `inspect_stack.pop()` if pushed
    end

    def pretty_print(o)
      klass = `Object.prototype.toString.apply(self.native)`
      klass =~ /^\[object (.*?)\]$/
      o.group(1, "#<#{self.class.name} #{Regexp.last_match(1) || klass}", '>') do
        o.breakable
        o.pp(to_h)
      end
    end

    def method_missing(method, *args, &block)
      if method.end_with? '='
        raise ArgumentError, 'JS attr assignment needs 1 argument' if args.length != 1
        js_property_set(method[0..-2], args.first)
      elsif js_property?(method)
        args << block if block_given?
        js_property(method, args: args)
      else
        super
      end
    end

    def respond_to_missing?(method, include_all = true)
      if method.end_with?('=') || js_property?(method)
        true
      else
        super
      end
    end

    def raw(raw = true)
      self.dup.tap do |i|
        i.instance_variable_set(:@js_raw_naming, true)
      end
    end
  end

  module ArrayWrapper
    include Enumerable
    include ObjectWrapper

    def each(&block)
      return enum_for(:each) { length } unless block_given?

      %x{
        for (var i = 0; i < self.native.length; i++) {
          Opal.yield1(block, #{JSWrap(`self.native[i]`, self)});
        }
      }
      self
    end

    def [](key)
      if key.is_a? Number
        JSWrap.wrap(`self.native[key]`, self)
      else
        super
      end
    end

    def []=(key, kwargs = {}, value)
      if key.is_a? Number
        `self.native[key] = #{JSWrap.unwrap(value, self)}`
      else
        super
      end
    end

    def <<(value)
      `Array.prototype.push.apply(self.native, [#{JSWrap.unwrap(value, self)}])`
      self
    end

    alias append <<

    def length
      `self.native.length`
    end

    def inspect
      if `inspect_stack`.include?(__id__)
        inside = '[...]'
      else
        `inspect_stack` << __id__
        pushed = true
        inside = to_a.inspect
      end
      klass = `Object.prototype.toString.apply(self.native)`
      klass =~ /^\[object (.*?)\]$/
      "#<#{self.class.name} #{Regexp.last_match(1) || klass} #{inside}>"
    ensure
      `inspect_stack.pop()` if pushed
    end

    def pretty_print(o)
      klass = `Object.prototype.toString.apply(self.native)`
      klass =~ /^\[object (.*?)\]$/
      o.group(1, "#<#{self.class.name} #{Regexp.last_match(1) || klass}", '>') do
        o.breakable
        o.pp(to_a)
      end
    end
  end

  module FunctionWrapper
    include ObjectWrapper

    def call(*args, &block)
      JSWrap.call(@native_parent, @native, *args, &block)
    end

    def to_proc
      proc do |*args, &block|
        call(*args, &block)
      end
    end

    def inspect
      if `typeof self.native.toString !== 'function'`
        super
      else
        fundesc = `self.native.toString()`.split('{').first.strip.delete("\n")
        "#<#{self.class.name} #{fundesc}>"
      end
    end

    def pretty_print(o)
      if `typeof self.native.toString !== 'function'`
        super
      else
        o.text(inspect)
      end
    end
  end

  module RawClassWrapper
    include Wrapper

    def superclass
      JSWrap(`#{@native}.prototype.__proto__`, self)
    end
  end

  module ClassWrapper
    include FunctionWrapper
    include RawClassWrapper

    def const_missing(name)
      if js_property?(name)
        js_property(name)
      else
        super
      end
    end

    def new(*args, &block)
      args << block if block_given?
      args = JSWrap.unwrap_ary(args, self)
      JSWrap(`new (#{@native}.bind.apply(#{@native}, [null].concat(args)))`, self)
    end
  end

  def self.wrapped?(object)
    `object != null && '$$class' in object && Opal.is_a(object, Opal.JSWrap.Wrapper)`
  end

  def self.unwrap(object, parent = nil)
    %x{
      if (object === null || object === undefined || object === nil) {
        return null;
      }
      else if (object.$$class !== undefined) {
        // Opal < 1.4 bug: Opal.respond_to vs #respond_to_missing? does not call
        // #respond_to?
        if (object.$to_js !== undefined && !object.$to_js.$$stub) {
          return object.$to_js(parent);
        }
        else if (object.$to_n !== undefined && !object.$to_n.$$stub) {
          return object.$to_n();
        }
      }
      return object;
    }
  end

  def self.unwrap_ary(ary, parent = nil)
    %x{
      var i;
      for (i = 0; i < ary.length; i++) {
        ary[i] = #{unwrap(ary[`i`], parent)}
      }
      return ary;
    }
  end

  def self.unwrap_proc(proc, parent = nil)
    %x{
      var f = (function() {
        var i, ary = Array.prototype.slice.apply(arguments), ret;
        for (i = 0; i < ary.length; i++) {
          ary[i] = #{wrap(`ary[i]`, parent)}
        }
        ret = proc.apply(null, ary);
        return #{unwrap(`ret`, parent)}
      });
      f.$$proc_unwrapped = proc;
      return f;
    }
  end

  def self.wrap(object, parent = nil, args = nil, name: nil)
    %x{
      var i, out, wrapping;
      for (i = self.wrappings.length - 1; i >= 0; i--) {
        wrapping = self.wrappings[i];
        if (wrapping.block !== nil) {
          out = #{`wrapping.block`.call(object, parent, args, name)}
          if (out == null) return nil;
          else if (out !== nil) return out;
        }
        else if (object instanceof wrapping.js_constructor) {
          return #{`wrapping.opal_klass`.wrap(`object`)}
        }
      }
    }
  end

  def self.call(parent, item, *args, &block)
    args << block if block_given?
    orig_parent = parent
    parent = unwrap(parent, orig_parent)
    args = unwrap_ary(args, orig_parent)
    %x{
      if (typeof item !== 'function') {
        item = parent[item];
      }
      item = item.apply(parent, args);
      return #{wrap(item, orig_parent)}
    }
  end

  @wrappings = []
  def self.register_wrapping(opal_klass = undefined, js_constructor = undefined, priority: 0, &block)
    @wrappings << `{
      priority: priority,
      opal_klass: opal_klass,
      js_constructor: js_constructor,
      block: block
    }`
    @wrappings.sort_by!(&`function(i){
                          return -i.priority;
                        }`
                       )
  end

  module WrapperClassMethods
    include RawClassWrapper
  end

  class ObjectView
    extend WrapperClassMethods
    include ObjectWrapper
    self.js_array_wrap = true
    undef Array, String, load
  end
  class ArrayView
    extend WrapperClassMethods
    include ArrayWrapper
    self.js_array_wrap = true
  end
  # ClassView does not work as a class fully. This is only a limited contract.
  # ie. ClassView.wrap(`BigInt`).new.class == ObjectView.
  # The reason why we inherit from Class is that so we can access properties like A::B
  class ClassView < Class
    extend WrapperClassMethods
    include ClassWrapper
    self.js_array_wrap = true
  end
  class FunctionView
    extend WrapperClassMethods
    include FunctionWrapper
    self.js_array_wrap = true
  end
end

module Kernel
  def JSWrap(*args, &block)
    JSWrap.wrap(*args, &block)
  end
end

JSWrap.register_wrapping(priority: -10) do |item, parent, args, name|
  %x{
    var type = typeof item;

    var array_wrap = $truthy(parent) ? $truthy(parent.$js_array_wrap()) : true;
    var function_wrap = $truthy(parent) ? $truthy(parent.$js_function_wrap()) : false;

    if (type === 'undefined' || item === null || item === nil) {
      // A special case not documented anywhere: null makes it dispatch a nil.
      if (args !== nil && args.length !== 0) {
        #{raise ArgumentError, 'given args while dispatching a null value'}
      }
      return null;
    }
    else if (type === 'symbol' || type === 'bigint') {
      // As of Opal 1.4, we don't support those. Let's pretend they
      // are just objects.
      if (args !== nil && args.length !== 0) {
        #{raise ArgumentError, "given args while dispatching a #{`type`}"}
      }
      return #{JSWrap::ObjectView.wrap(item, parent)}
    }
    else if (type === 'number' || type === 'string' || type === 'boolean') {
      // Otherwise it's some primitive and it's wrapped
      if (args !== nil && args.length !== 0) {
        #{raise ArgumentError, "given args while dispatching a #{`type`}"}
      }
      return item;
    }
    else if ('$$js_wrap' in item) {
      // Wrapping is dispatched already, we can trust it to be wrapped properly
      if (args !== nil && args.length !== 0) {
        #{raise ArgumentError, 'given args while dispatching an already dispatched value'}
      }
      return item.$$js_wrap;
    }
    else if (type === 'function') {
      if (item.$$class === Opal.Class) {
        // Opal Class
        if (args !== nil && args.length !== 0) {
          #{raise ArgumentError, 'given args while dispatching an Opal class'}
        }
        return item;
      }
      else if ("$$arity" in item) {
        // Native Opal proc
        return item;
      }
      else if ("$$proc_unwrapped" in item) {
        // Unwrapped native Opal proc
        return item.$$proc_unwrapped;
      }
      else if (name !== nil && 'prototype' in item && name.match(/^[A-Z]/)) {
        // Class
        // There is no reliable way to detect a JS class. So we check if its
        // name starts with an uppercase letter.
        if (args !== nil && args.length !== 0) {
          #{raise ArgumentError, 'given args while dispatching a class'}
        }
        return #{JSWrap::ClassView.wrap(item, parent)}
      }
      else {
        // Regular function
        if (function_wrap || args === nil) {
          return #{JSWrap::FunctionView.wrap(item, parent)}
        }
        else {
          var ret = #{JSWrap.call(parent, item, *args)}
          return ret === nil ? null : ret;
        }
      }
    }
    else if (type === 'object') {
      if (item instanceof Array) {
        // A regular array
        if (args !== nil && args.length !== 0) {
          #{raise ArgumentError, 'given args while dispatching an array'}
        }
        if (array_wrap) {
          return #{JSWrap::ArrayView.wrap(item, parent)}
        }
        else {
          return item;
        }
      }
      else if ('$$class' in item) {
        // Opal item
        if (args !== nil && args.length !== 0) {
          #{raise ArgumentError, 'given args while dispatching an Opal object'}
        }
        return item;
      }
      else {
        // Pass.
        return nil;
      }
    }
    else {
      #{raise ArgumentError, "unknown value type #{type}"}
    }
  }
end

# Now custom wrappers run... but if nothing is found... we run a
# final wrapper:

JSWrap.register_wrapping(priority: 10) do |item, parent, args|
  %x{
    if (args !== nil && args.length !== 0) {
      #{raise ArgumentError, 'given args while dispatching an object'}
    }
    else if ('length' in item) {
      // A pseudo-array, we always wrap those
      return #{JSWrap::ArrayView.wrap(item, parent)}
    }
    else {
      // Otherwise it is a regulat object
      return #{JSWrap::ObjectView.wrap(item, parent)}
    }
  }
end

class Hash
  # @return a JavaScript object with the same keys but calling #to_js on
  # all values.
  def to_js(parent=nil)
    result = `{}`
    each do |k,v|
      key = parent ? parent.js_property_name_rb2js(k) : k
      `result[key] = #{JSWrap.unwrap(`v`, parent)}`
    end
    result
  end
end

class Array
  # Retuns a copy of itself trying to call #to_js on each member.
  def to_js(parent=nil)
    %x{
      var result = [];
      for (var i = 0, length = self.length; i < length; i++) {
        var obj = self[i];
        result.push(#{JSWrap.unwrap(`obj`, parent)});
      }
      return result;
    }
  end
end

class Method
  def to_js(parent=nil)
    JSWrap.unwrap_proc(to_proc, parent)
  end
end

class Proc
  def to_js(parent=nil)
    %x{
      // Is this a native Opal Proc? Or is it JavaScript
      // created?
      if ('$$arity' in self) {
        return #{JSWrap.unwrap_proc(self, parent)}
      }
      else {
        return self;
      }
    }
  end
end

JSGlobal = JSWrap(`Opal.global`)
