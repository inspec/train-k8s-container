# frozen_string_literal: true
require "train"
require "train/file/remote/linux"
module Train
  module K8s
    module Container
      class Connection < Train::Plugins::Transport::BaseConnection

        # URI format: k8s-container://<namespace>/<pod>/<container_name>
        # @example k8s-container://default/shell-demo/nginx

        def initialize(options)
          super(options)
          uri_path = options[:path]&.gsub(%r{^/}, "")
          @pod = options[:pod] || uri_path&.split("/")&.first
          @container_name = options[:container_name] || uri_path&.split("/")&.last
          host = (!options[:host].nil? && !options[:host].empty?) ? options[:host] : nil
          @namespace = options[:namespace] || host || Train::K8s::Container::KubectlExecClient::DEFAULT_NAMESPACE
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

        def unique_identifier
          @unique_identifier ||= "#{@container_name}_#{@pod}"
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

        def file_via_connection(path, *_args)
          ::Train::File::Remote::Linux.new(self, path)
        end
      end
    end
  end
end
