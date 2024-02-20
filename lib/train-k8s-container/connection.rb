# frozen_string_literal: true
require "train"
require_relative "platform"

require "train/plugins"
#require "train/file/remote/linux"
module TrainPlugins
  module K8sContainer
    class Connection < Train::Plugins::Transport::BaseConnection
      #include TrainPlugins::K8sContainer::Platform
      include Train::Platforms::Common
      #include_options Train::Extras::CommandWrapper

      # URI format: k8s-container://<namespace>/<pod>/<container_name>
      # @example k8s-container://default/shell-demo/nginx

      def initialize(options)
        super(options)

        if RUBY_PLATFORM =~ /windows|mswin|msys|mingw|cygwin/
          raise "Unsupported host platform."
        end

        uri_path = options[:path]&.gsub(%r{^/}, "")
        @pod = options[:pod] || uri_path&.split("/")&.first
        @container_name = options[:container_name] || uri_path&.split("/")&.last
        host = (!options[:host].nil? && !options[:host].empty?) ? options[:host] : nil
        @namespace = options[:namespace] || host || Train::K8s::Container::KubectlExecClient::DEFAULT_NAMESPACE
        validate_parameters
      end

      def uri
        "k8s-container://#{@namespace}/#{@pod}/#{@container_name}"
      end

      def platform
        require 'byebug'; byebug
        @platform ||= Train::Platforms::Detect.scan(self)
      end

      private

      attr_reader :pod, :container_name, :namespace


      def run_command_via_connection(cmd, &_data_handler)
        KubectlExecClient.new(pod: pod, namespace: namespace, container_name: container_name).execute(cmd)
      end

      def validate_parameters
        raise ArgumentError, "Missing Parameter `pod`" unless pod
        raise ArgumentError, "Missing Parameter `container_name`" unless container_name
      end

      def file_via_connection(path, *_args)
        #::Train::File::Remote::Linux.new(self, path)
      end
    end
  end
end
