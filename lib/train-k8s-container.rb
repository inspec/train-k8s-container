# frozen_string_literal: true

require_relative "train/k8s/container/version"
require_relative "train/k8s/container/platform"
require_relative "train/k8s/container/connection"
require_relative "train/k8s/container/transport"
require_relative "train/k8s/container/kubectl_exec_client"

module Train
  module K8s
    module Container
      class ConnectionError < StandardError
      end
      # Your code goes here...
    end
  end
end
