# backtick_javascript: true

require "js_wrap"
require "js_wrap/three/three" # JavaScript

ThreeMod = JSWrap::ClassView.wrap(`THREE`)

module Three
  class Three::Object3D < JSWrap::ObjectView
    js_class `THREE.Object3D`

    self.js_array_wrap = true

    def <<(other)
      add(other)
      self
    end
  end

  # A hack for UMD exporting things in globalThis
  def self.const_missing(name)
    if ThreeMod.js_property?(name)
      ThreeMod.js_property(name)
    elsif JSGlobal.js_property?(name)
      JSGlobal.js_property(name).js_property(name)
    else
      super
    end
  end

  def self.method_missing(*args, &block)
    ThreeMod.send(*args, &block)
  end
end

