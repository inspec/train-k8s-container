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

        attr_reader :session

        def ensure_session_open
          start_session unless session && !session.closed?
        end

        def stream(command)
          session.puts("#{command}; echo KUBECTL_EXEC_STATUS:$?; echo KUBECTL_EXEC_DONE")
          output = ""
          exit_status = nil
          while (line = session.gets)
            if line.start_with?("KUBECTL_EXEC_STATUS:")
              exit_status = line.chomp.split(":")[1].to_i
            elsif line.chomp == "KUBECTL_EXEC_DONE"
              break
            else
              output += line
            end
          end
          if exit_status.nil?
            puts "Error: Failed to retrieve exit status."
          else
            stdout, stderr = if exit_status == 0
                               [output, ""]
                             else
                               ["", output]
                             end
          end
          Train::Extras::CommandResult.new(stdout, stderr, exit_status)
        end

        def start_session
          @session = IO.popen(exec_command, "r+")
          # TODO: check if kubectl connection is established
          raise "Failed to open connection" unless @session
        end

        def exec_command
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
            arr << "/bin/sh"
          end.join("\s")
        end

        def sh_run_command(command)
          %W{/bin/sh -c "#{command}"}
        end
      end
    end
  end
end
