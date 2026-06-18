# frozen_string_literal: true
libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require_relative "train-k8s-container/version"
require_relative "train-k8s-container/connection"
require_relative "train-k8s-container/transport"
require_relative "train-k8s-container/kubectl_exec_client"

# module TrainPlugins
#   module K8sContainer
#     class ConnectionError < StandardError
#       # Your code goes here...
#     end
#   end
# end
