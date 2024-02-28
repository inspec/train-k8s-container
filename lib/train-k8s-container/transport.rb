# frozen_string_literal: true
require "train"
require "train/plugins"

module TrainPlugins
  module K8sContainer
    class Transport < Train.plugin(1)
      require_relative "connection"

      name "k8s-container"

      option :kubeconfig, default: ENV["KUBECONFIG"] || "~/.kube/config"
      option :pod, default: nil
      option :container_name, default: nil
      option :namespace, default: nil

      def connection(state = nil, &block)
        opts = merge_options(@options, state || {})
        create_new_connection(opts, &block)
      end

      def create_new_connection(options, &block)
        @connection_options = options
        @connection = Connection.new(options, &block)
      end
    end
  end
end
