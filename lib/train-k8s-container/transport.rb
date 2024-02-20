# frozen_string_literal: true
require "train"
require "train/plugins"



module TrainPlugins
  module K8sContainer
    class Transport < Train.plugin(1)
      require_relative "connection"

      #name Train::K8s::Container::Platform::PLATFORM_NAME
      #include_options Train::Extras::CommandWrapper
      
      name "k8s-container"

      option :kubeconfig, default: ENV["KUBECONFIG"] || "~/.kube/config"
      option :pod, default: nil
      option :container_name, default: nil
      option :namespace, default: nil


      def connection(state = nil, &block)
        opts = merge_options(@options, state || {})
        #validate_options(opts)
        #conn_opts = connection_options(opts)

        # if @connection && @connection_options == conn_opts
        #   reuse_connection(&block)
        # else
        create_new_connection(opts, &block)
        # end
      end
      # def connection(_instance_opts = nil)
      #   @connection ||= TrainPlugins::K8sContainer::Connection.new(@options)
      # end

      def create_new_connection(options, &block)
        # if @connection
        #   logger.debug("[WinRM] shutting previous connection #{@connection}")
        #   @connection.close
        # end

        @connection_options = options
        @connection = Connection.new(options, &block)
      end
    end
  end
end
