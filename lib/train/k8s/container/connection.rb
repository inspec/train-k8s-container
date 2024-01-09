# frozen_string_literal: true
require "train"
module Train
  module K8s
    module Container
      class Connection < Train::Plugins::Transport::BaseConnection
        include Train::K8s::Container::Platform

        def initialize(options)
          super(options)
          @pod = options[:pod] || options[:path]&.gsub("/", "")
          @container_name = options[:container_name]
          @namespace = options[:namespace] || options[:host]
          connect
        end

        def connect; end

        private

        attr_reader :pod, :container_name, :namespace
      end
    end
  end
end
