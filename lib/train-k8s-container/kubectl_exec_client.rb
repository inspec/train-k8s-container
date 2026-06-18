require "mixlib/shellout" unless defined?(Mixlib::ShellOut)
require "train/options" # only to load the following requirement `train/extras`
require "train/extras"
require "open3"
require "pty"
require "expect"

module Train
  module K8s
    module Container
      class KubectlExecClient
        attr_reader :pod, :container_name, :namespace, :reader, :writer, :pid

        DEFAULT_NAMESPACE = "default".freeze
        @@session = {}

        def initialize(pod:, namespace: nil, container_name: nil)
          @pod = pod
          @container_name = container_name
          @namespace = namespace

          @reader = @@session[:reader] || nil
          @writer = @@session[:writer] || nil
          @pid = @@session[:pid] || nil
          connect if @@session.empty?
        end

        def connect
          @reader, @writer, @pid = PTY.spawn("kubectl exec --stdin --tty #{@pod} -n #{@namespace} -c #{@container_name} -- /bin/bash")
          @writer.sync = true
          @@session[:reader] = @reader
          @@session[:writer] = @writer
          @@session[:pid] = @pid
        rescue StandardError => e
          puts "Error connecting: #{e.message}"
          sleep 1
          retry
        end

        def reconnect
          disconnect
          connect
        end

        def disconnect
          @writer.puts "exit" if @writer
          [@reader, @writer].each do |io|
            io.close if io && !io.closed?
          end
          @@session = {}
        rescue IOError
          Train::Extras::CommandResult.new("", "", 1)
        end

        def strip_ansi_sequences(text)
          text.gsub(/\e\[.*?m/, "").gsub(/\e\]0;.*?\a/, "").gsub(/\e\[A/, "").gsub(/\e\[C/, "").gsub(/\e\[K/, "")
        end

        def send_command(command)
          cmd_string = "#{command} 2>&1 ; echo EXIT_CODE=$?"
          @writer.puts(cmd_string)
          @writer.flush

          stdout = ""
          stderr = ""
          status = nil
          buffer = ""

          begin
            while (line = @reader.gets)
              buffer << line
              if line =~ /EXIT_CODE=(\d+)/
                status = $1.to_i
                break
              elsif line =~ /bash: syntax error/
                status = 2
                break
              end
            end
          rescue Errno::EIO => e
            raise StandardError, e.message
          end

          # Clean up the buffer by removing ANSI escape sequences
          buffer = strip_ansi_sequences(buffer)
          # Process the buffer to remove the command echo and the EXIT_CODE
          stdout_lines = buffer.lines
          # TODO: there is a known bug with this approach and that is if an executable that is not found in the
          # environment is tried and executed, then it will remove not be present in the STDERR, because the following
          # line filters that exact command as well for example,
          # for the command 'foo'
          # `["bash: foo: command not found\r\n"].reject! { |l| l =~ /#{Regexp.escape('foo')}/ }` returns an empty []
          stdout_lines.reject! { |l| l =~ /#{Regexp.escape(command)}/ }
          stdout_lines.reject! { |l| l =~ /EXIT_CODE=/ }

          # Separate stdout and stderr
          if status != 0
            stderr = stdout_lines.join.strip
            stdout = ""
          else
            stdout = stdout_lines.join.strip
          end

          Train::Extras::CommandResult.new(stdout, stderr, status)
        end

        def execute(command)
          send_command(command)
        rescue StandardError => e
          reconnect
          Train::Extras::CommandResult.new("", e.message, 1)
        end

        def close
          disconnect
        end
      end
    end
  end
end

