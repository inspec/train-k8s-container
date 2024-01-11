# frozen_string_literal: true

module Train
  module K8s
    module Container
      class Transport < Train.plugin(1)

        name Train::K8s::Container::Platform::PLATFORM_NAME
        option :kubeconfig, default: ENV["KUBECONFIG"] || "~/.kube/config"
        option :pod, default: nil
        option :container_name, default: nil
        option :namespace, default: nil
        def connection(_instance_opts = nil)
          @connection ||= Train::K8s::Container::Connection.new(@options)
        end
      end
    end
  end
end
