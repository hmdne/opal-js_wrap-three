# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

file 'lib-opal/js_wrap/three/three.js' do
  sh 'npx rollup -c'
end

task build_js: 'lib-opal/js_wrap/three/three.js'

task default: %i[build_js]
