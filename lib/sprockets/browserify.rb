require 'sprockets'
require 'tilt'
require 'pathname'

module Sprockets
  Config = Struct.new()

  # Postprocessor that runs the computed source of Javascript files
  # through browserify, resulting in a self-contained files including all
  # referenced modules
  class Browserify < Tilt::Template

    def prepare
    end

    def evaluate(scope, locals, &block)
      if process_asset?(scope)
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

    def process_asset?(scope)
      (scope.pathname.dirname+'package.json').exist?
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
        '--debug' # @TODO make this configurable
      ]
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
      # kinda not clean...
      ::Rails.application.config.sprockets_browserify
    end
  end
end
