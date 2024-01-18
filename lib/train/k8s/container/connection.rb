# frozen_string_literal: true
require "train"
module Train
  module K8s
    module Container
      class Connection < Train::Plugins::Transport::BaseConnection
        include Train::K8s::Container::Platform

        # URI format: k8s-container://<namespace>/<pod>/<container_name>
        # @example k8s-container://default/shell-demo/nginx

        DEFAULT_NAMESPACE = "default"

        def initialize(options)
          super(options)
          uri_path = options[:path]&.gsub(%r{^/}, "")
          @pod = options[:pod] || uri_path&.split("/")&.first
          @container_name = options[:container_name] || uri_path&.split("/")&.last
          host = options[:host] unless options[:host].empty? || options[:host].nil?
          @namespace = options[:namespace] || host || DEFAULT_NAMESPACE
          validate_parameters
          connect
        end

        def connect
          cmd_result = run_command_via_connection("uname")
          if cmd_result.exit_status > 0
            raise ConnectionError, cmd_result.stderr
          else
            self
          end
        end

        private

        attr_reader :pod, :container_name, :namespace

        def validate_parameters
          raise ArgumentError, "Missing Parameter `pod`" unless pod
          raise ArgumentError, "Missing Parameter `container_name`" unless container_name
        end

        def run_command_via_connection(cmd, &_data_handler)
          KubectlExecClient.new(pod: pod, namespace: namespace, container_name: container_name).execute(cmd)
        end
      end
    end
  end
end
