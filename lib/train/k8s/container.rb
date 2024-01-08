# frozen_string_literal: true

require_relative "container/version"
require_relative "container/kubectl_exec_client"

module Train
  module K8s
    module Container
      class Error < StandardError; end
      # Your code goes here...
    end
  end
end
