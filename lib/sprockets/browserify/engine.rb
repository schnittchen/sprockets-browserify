require 'sprockets/browserify'

if defined?(Rails)
  module Sprockets
    class Browserify

      class Engine < ::Rails::Engine
        initializer :setup_browserify, :after => "sprockets.environment", :group => :all do |app|
          app.assets.register_postprocessor 'application/javascript', Browserify
        end

        initializer "sprockets-browserify.init_config" do |app|
          config = app.config.sprockets_browserify = Config.new

          # this is ugly and should be replaced with a better mechanism.
          config.scope_matcher = ->(scope) { (scope.pathname.dirname+'package.json').exist? }
        end
      end

    end
  end
end
