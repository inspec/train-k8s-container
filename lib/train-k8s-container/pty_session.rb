# frozen_string_literal: true

require 'pty'
require 'timeout'
require 'securerandom'
require_relative 'errors'
require_relative 'ansi_sanitizer'

module TrainPlugins
  module K8sContainer
    # PTY-based persistent shell session for performance optimization
    # Maintains a single kubectl exec session instead of spawning per command
    class PtySession
      class PtyError < K8sContainerError; end
      class SessionClosedError < PtyError; end
      class CommandTimeoutError < PtyError; end

      attr_reader :session_key, :reader, :writer, :pid, :marker_id

      DEFAULT_COMMAND_TIMEOUT = 60
      DEFAULT_SESSION_TIMEOUT = 300

      def initialize(session_key:, kubectl_cmd:, shell: '/bin/bash', timeout: DEFAULT_SESSION_TIMEOUT, logger: nil)
        @session_key = session_key
        @kubectl_cmd = kubectl_cmd
        @shell = shell
        @timeout = timeout
        @command_timeout = DEFAULT_COMMAND_TIMEOUT
        # Logger is optional - all logging uses safe navigation (@logger&.method)
        @logger = logger
        @reader = nil
        @writer = nil
        @pid = nil
        # Unique marker per session prevents collision with user output
        # Uses 8-char hex (32 bits of entropy) - sufficient for session uniqueness
        @marker_id = SecureRandom.hex(4)
      end

      def connect
        raise SessionClosedError, 'Session already connected' if connected?

        @logger&.debug("Opening persistent session for #{@session_key} with #{@shell}")
        @reader, @writer, @pid = PTY.spawn("#{@kubectl_cmd} -- #{@shell}")
        @writer.sync = true

        # Wait briefly for shell to be ready (no prompt expected without --tty)
        sleep(0.1)

        @logger&.debug("Persistent session established (PID: #{@pid})")
        true
      rescue StandardError => e
        cleanup
        raise PtyError, "Failed to connect: #{e.message}"
      end

      def connected?
        @reader && @writer && !@reader.closed? && !@writer.closed?
      end

      def healthy?
        return false unless connected?

        begin
          Process.kill(0, @pid)
          true
        rescue Errno::ESRCH
          false
        end
      end

      def execute(command)
        raise SessionClosedError, 'Session not connected' unless connected?
        raise SessionClosedError, 'Session unhealthy' unless healthy?

        @logger&.debug("Executing in PTY session: #{command}")

        # Send command with unique exit code marker (prevents collision with user output)
        cmd_with_marker = "#{command} 2>&1 ; echo #{exit_marker}=$?"
        @writer.puts(cmd_with_marker)
        @writer.flush

        # Read output until exit code marker
        output = read_until_marker
        parse_output(output, command)
      rescue Errno::EIO => e
        raise SessionClosedError, "Connection lost: #{e.message}"
      rescue Timeout::Error
        raise CommandTimeoutError, "Command timed out after #{@command_timeout}s"
      end

      def disconnect
        return unless connected?

        @logger&.debug("Closing PTY session #{@session_key}")
        begin
          @writer.puts 'exit' unless @writer.closed?
          @writer.close unless @writer.closed?
          @reader.close unless @reader.closed?
          Process.wait(@pid, Process::WNOHANG)
        rescue StandardError => e
          @logger&.warn("Error during disconnect: #{e.message}")
        ensure
          @reader = nil
          @writer = nil
          @pid = nil
        end
      end

      alias cleanup disconnect

      private

      # Unique exit code marker for this session
      # Format: __EXIT_CODE_<8-char-hex>__ (e.g., __EXIT_CODE_a1b2c3d4__)
      # This prevents any possible collision with user output
      def exit_marker
        "__EXIT_CODE_#{@marker_id}__"
      end

      # Regex pattern to match our unique marker
      def exit_marker_pattern
        /#{Regexp.escape(exit_marker)}=(\d+)/
      end

      # Wrapper suffix added to commands (for echo removal)
      def wrapper_suffix
        "2>&1 ; echo #{exit_marker}=$?"
      end

      def read_until_marker
        buffer = +'' # Unfreeze string
        marker_regex = exit_marker_pattern

        Timeout.timeout(@command_timeout) do
          while (line = @reader.gets)
            buffer << line
            break if line =~ marker_regex
          end
        end

        buffer
      end

      def parse_output(buffer, command)
        # Strip ANSI sequences
        cleaned = strip_ansi_sequences(buffer)

        # Extract exit code using our unique session marker
        exit_code = 1
        if (match = cleaned.match(exit_marker_pattern))
          exit_code = match[1].to_i
        end

        # Remove the exit code marker line
        cleaned = remove_marker_line(cleaned)

        # Remove command echo-back from PTY output
        # The shell echoes the command before executing, ending with our wrapper marker.
        # For multi-line commands, we can't use simple line matching - we need to find
        # the wrapper marker and remove everything up to and including it.
        output = remove_command_echo(cleaned, command)

        # Separate stdout/stderr based on exit code
        if exit_code.zero?
          Train::Extras::CommandResult.new(output.strip, '', exit_code)
        else
          Train::Extras::CommandResult.new('', output.strip, exit_code)
        end
      end

      # Remove echoed command from PTY output
      # PTY shells echo the command before output. Our wrapper adds:
      #   "#{command} 2>&1 ; echo #{exit_marker}=$?"
      # The shell echoes this, then outputs the result. We need to find
      # where the echo ends and the actual output begins.
      def remove_command_echo(text, command)
        # The wrapper marker that ends our command echo (unique per session)
        wrapper = wrapper_suffix

        # Strategy 1: Find the wrapper marker (handles multi-line commands)
        # Everything before and including this line is command echo
        marker_index = text.index(wrapper)
        if marker_index
          newline_after_marker = text.index("\n", marker_index)
          return '' if newline_after_marker.nil?

          # Everything after the marker line is actual output
          output = text[(newline_after_marker + 1)..]
        else
          # Strategy 2: Fall back to line-by-line removal (handles simple cases)
          # This is used when the marker isn't present (e.g., some test scenarios)
          output = text
        end

        # Also remove simple command echo if still present
        # (some shells may echo the command on its own line)
        lines = output.lines
        lines.reject! { |l| l.strip == command.strip }
        lines.join
      end

      # Remove the line containing our unique exit code marker
      def remove_marker_line(text)
        lines = text.lines
        marker_regex = exit_marker_pattern
        marker_idx = lines.rindex { |line| line =~ marker_regex }
        lines.delete_at(marker_idx) if marker_idx
        lines.join
      end

      def strip_ansi_sequences(text)
        AnsiSanitizer.sanitize(text)
      end
    end
  end
end
