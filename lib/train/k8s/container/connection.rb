# frozen_string_literal: true

module Train
  module K8s
    module Container
      class Connection < Train::Plugins::Transport::BaseConnection

        def initialize(options)
          super(options)
          @pod = options[:pod] || options[:path]&.gsub('/', '')
          @container = options[:container_name]
          @namespace = options[:namespace] || options[:host]
        end
      end
    end
  end
end
