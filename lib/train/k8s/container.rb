# frozen_string_literal: true

require_relative "container/version"
require_relative "container/platform"
require_relative "container/connection"
require_relative "container/transport"
require_relative "container/kubectl_exec_client"

module Train
  module K8s
    module Container
      class ConnectionError < StandardError
      end
      # Your code goes here...
    end
  end
end
