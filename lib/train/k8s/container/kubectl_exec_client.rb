require "mixlib/shellout" unless defined?(Mixlib::ShellOut)
require "train/options" # only to load the following requirement `train/extras`
require "train/extras"

module Train
  module K8s
    module Container
      class KubectlExecClient
        attr_reader :pod, :container_name, :namespace

        DEFAULT_NAMESPACE = "default".freeze

        def initialize(pod:, namespace: nil, container_name: nil)
          @pod = pod
          @container_name = container_name
          @namespace = namespace
        end

        def execute(command)
          instruction = build_instruction(command)
          shell = Mixlib::ShellOut.new(instruction)
          res = shell.run_command
          Train::Extras::CommandResult.new(res.stdout, res.stderr, res.exitstatus)
        rescue Errno::ENOENT => _e
          Train::Extras::CommandResult.new("", "", 1)
        end

        private

        def build_instruction(command)
          ["kubectl exec"].tap do |arr|
            arr << "--stdin"
            arr << pod if pod
            if namespace
              arr << "-n"
              arr << namespace
            end
            if container_name
              arr << "-c"
              arr << container_name
            end
            arr << "--"
            arr << sh_run_command(command)
          end.join("\s")
        end

        def sh_run_command(command)
          %W{/bin/sh -c "#{command}"}
        end
      end
    end
  end
end
