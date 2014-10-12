=begin
Copyright (c) 2014 Magnus Holm

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

# https://raw.githubusercontent.com/judofyr/minitest-line/master/lib/minitest/line_plugin.rb
# HACKS: added https://github.com/judofyr/minitest-line/pull/5
require 'pathname'

module Minitest
  def self.plugin_line_options(opts, options)
    opts.on '-l', '--line N', Integer, "Run test at line number" do |lineno|
      options[:line] = lineno
    end
  end

  def self.plugin_line_init(options)
    exp_line = options[:line]
    if !exp_line
      reporter.reporters << LineReporter.new
      return
    end

    methods = Runnable.runnables.flat_map do |runnable|
      runnable.runnable_methods.map do |name|
        [name, runnable.instance_method(name)]
      end
    end.uniq

    current_filename = nil
    tests = {}

    methods.each do |name, meth|
      next unless loc = meth.source_location
      current_filename ||= loc[0]
      next unless current_filename == loc[0]
      tests[loc[1]] = name
    end

    _, main_test = tests.sort_by { |k, v| -k }.detect do |line, name|
      exp_line >= line
    end

    raise "Could not find test method after line #{exp_line}" unless main_test

    options[:filter] = main_test
  end

  class LineReporter < Reporter
    def initialize(*)
      super
      @failures = []
    end

    def record(result)
      if !result.skipped? && !result.passed?
        @failures << result
      end
    end

    def report
      return unless @failures.any?
      io.puts
      io.puts "Focus on failing tests:"
      pwd = Pathname.new(Dir.pwd)
      @failures.each do |res|
        meth = res.method(res.name)
        file, line = meth.source_location
        if file
          file = Pathname.new(file)
          file = file.relative_path_from(pwd) if file.absolute?
          output = "ruby #{file} -l #{line}"
          output = "\e[31m#{output}\e[0m" if $stdout.tty?
          io.puts output
        end
      end
    end
  end

  def self.plugin_line_inject_reporter
  end
end