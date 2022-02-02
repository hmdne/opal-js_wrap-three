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

task :build_js_examples do
  Dir["node_modules/three/examples/jsm/**/*.js"].each do |js|
    sh "npx babel #{js} -o lib-opal/js_wrap/three/#{js.split("/jsm/").last}"
  end
end

task default: %i[build_js build_js_examples]

task :build_gh_pages do
  require 'fileutils'

  output_dir = __dir__+"/gh-pages/examples/"
  FileUtils.mkdir_p output_dir

  Dir['examples/*'].each do |example_path|
    example = File.basename(example_path)

    output_example_dir = output_dir+"/"+example
    FileUtils.mkdir_p output_example_dir

    Dir.chdir(example_path) do
      `bundle exec opal -qopal/js_wrap/three -c example.rb > #{output_example_dir}/app.js`
      File.write("#{output_example_dir}/index.html", <<~HTML)
        <!DOCTYPE html>
        <html>
          <head>
            <style> body { margin: 0; } </style>
            <script src="app.js"></script>
          </head>
          <body></body>
        </html>
      HTML
    end
  end
end