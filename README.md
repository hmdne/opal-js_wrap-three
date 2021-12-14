# Opal-JSWrap-Three

This gem wraps the Three.js library with JSWrap for Opal.

Releases before v0.2.0 should support all versions of Opal and
bundle JSWrap. Later versions will use Opal-bundled version of
JSWrap.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'opal-jswrap-three'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install opal-jswrap-three

## Usage

Server-side:

```ruby
require 'opal/js_wrap/three'
```

Client-side:

```ruby
require 'js_wrap/three'
```

Three.js API follows, except that everything named like `setSize`
is now `set_size` and so on.

See examples for more info.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hmdne/opal-jswrap-three.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
