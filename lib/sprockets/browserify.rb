require 'sprockets'
require 'tilt'
require 'pathname'

module Sprockets
  class Config
    attr_accessor :scope_matcher, :enable_source_maps, :pre_hook

    def initialize
      self.scope_matcher = ->(scope) { (scope.pathname.dirname+'package.json').exist? }
      self.pre_hook = ->(scope) {}
    end
  end

  # Postprocessor that runs the computed source of Javascript files
  # through browserify, resulting in a self-contained files including all
  # referenced modules
  class Browserify < Tilt::Template

    def prepare
    end

    def evaluate(scope, locals, &block)
      if process_asset?(scope)
        call_pre_hook(scope)

        deps = browserify_output(*browserify_list_cmd(scope.pathname.to_s)) do |exit|
          raise "Error finding dependencies"
        end

        deps.lines.drop(1).each{|path| scope.depend_on path.strip}

        @output ||= browserify_output(*browserify_process_command(scope.pathname.to_s)) do |exit|
          raise "Error compiling dependencies"
        end

        @output
      else
        data
      end
    end

  protected

    def call_pre_hook(scope)
      config.pre_hook.call(scope)
    end

    def process_asset?(scope)
      config.scope_matcher.call(scope)
    end

    def source_maps?
      config.enable_source_maps
    end

    def browserify_list_cmd(file)
      [
        file,
        '--list', '-t', 'coffeeify', '--extension=.coffee'
      ]
    end

    def browserify_process_command(file)
      [
        file,
        '-t', 'coffeeify', '--extension=.coffee',
        source_maps? ? '--debug' : nil
      ].compact
    end

    def browserify_output(*args)
      r, w = IO.pipe
      pid = spawn(browserify_executable.to_s, *args, out: w, chdir: gem_dir)
      w.close
      result = r.read
      r.close
      Process.wait(pid)
      exit_status = $?

      yield(exit_status) unless exit_status.success?
      result
    end

    def gem_dir
      @gem_dir ||= Pathname.new(__FILE__).dirname + '../..'
    end

    def browserify_executable
      @browserify_executable ||= gem_dir + 'node_modules/browserify/bin/cmd.js'
    end

    def config
      self.class.config
    end

    def self.config
      @config ||= Config.new
    end

    def self.configure
      yield config
    end
  end
end
