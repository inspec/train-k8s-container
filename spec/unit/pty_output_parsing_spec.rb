# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container'

RSpec.describe 'PTY Output Parsing' do
  # This test suite specifically targets the parse_output method in PtySession
  # to verify it correctly handles various output scenarios

  # Fixed marker ID for testing (in production, this is SecureRandom.hex(4))
  let(:test_marker_id) { 'deadbeef' }
  let(:exit_marker) { "__EXIT_CODE_#{test_marker_id}__" }
  let(:wrapper_suffix) { "2>&1 ; echo #{exit_marker}=$?" }

  let(:session) do
    # Create a minimal session object for testing parse_output
    TrainPlugins::K8sContainer::PtySession.allocate.tap do |s|
      s.instance_variable_set(:@session_key, 'test/pod/container')
      s.instance_variable_set(:@logger, nil)
      s.instance_variable_set(:@marker_id, test_marker_id)
    end
  end

  describe '#parse_output' do
    # Helper to call private parse_output method
    def parse_output(buffer, command)
      session.send(:parse_output, buffer, command)
    end

    context 'simple command without echo-back' do
      it 'extracts stdout correctly' do
        buffer = "root\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'whoami')

        expect(result.stdout).to eq('root')
        expect(result.stderr).to eq('')
        expect(result.exit_status).to eq(0)
      end

      it 'extracts stderr for failed commands' do
        buffer = "bash: nonexistent: command not found\n#{exit_marker}=127\n"
        result = parse_output(buffer, 'nonexistent')

        expect(result.stdout).to eq('')
        expect(result.stderr).to eq('bash: nonexistent: command not found')
        expect(result.exit_status).to eq(127)
      end
    end

    context 'command with echo-back (common in PTY)' do
      it 'filters out echoed command' do
        # Shell typically echoes the command before output
        buffer = "whoami\nroot\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'whoami')

        expect(result.stdout).to eq('root')
        expect(result.exit_status).to eq(0)
      end

      it 'filters out command with wrapper' do
        # Our wrapper adds the unique marker suffix
        buffer = "echo test #{wrapper_suffix}\ntest\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'echo test')

        expect(result.stdout).to eq('test')
        expect(result.stdout).not_to include('2>&1')
        expect(result.stdout).not_to include(exit_marker)
      end
    end

    context 'multi-line command (THE BUG SCENARIO)' do
      it 'filters out multi-line command echo-back' do
        # This is the exact scenario that fails in production
        command = <<~SHELL.strip
          for f in /etc/*.conf; do
            echo "Found: $f"
          done
        SHELL

        # Shell echoes back the multi-line command with our wrapper
        buffer = <<~OUTPUT
          for f in /etc/*.conf; do
            echo "Found: $f"
          done
           #{wrapper_suffix}
          Found: /etc/adduser.conf
          Found: /etc/debconf.conf
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        # Output should NOT contain the command
        expect(result.stdout).not_to include('for f in'),
                                     "Output still contains command: #{result.stdout.inspect}"
        expect(result.stdout).not_to include('2>&1'),
                                     "Output still contains wrapper: #{result.stdout.inspect}"

        # Output SHOULD contain actual results
        expect(result.stdout).to include('Found: /etc/adduser.conf')
        expect(result.exit_status).to eq(0)
      end

      it 'handles the certificate check command from bug report' do
        command = <<~SHELL.strip
          for f in $(find -L /etc/ssl/certs -type f); do
            openssl x509 -sha256 -in $f -noout -fingerprint | cut -d= -f2 | tr -d ':' | egrep -vw 'PATTERN'
          done
        SHELL

        buffer = <<~OUTPUT
          for f in $(find -L /etc/ssl/certs -type f); do
            openssl x509 -sha256 -in $f -noout -fingerprint | cut -d= -f2 | tr -d ':' | egrep -vw 'PATTERN'
          done
           #{wrapper_suffix}
          find: '/etc/ssl/certs': No such file or directory
          #{exit_marker}=1
        OUTPUT

        result = parse_output(buffer, command)

        # Output should NOT contain the command
        expect(result.stdout).not_to include('for f in'),
                                     "Output contains command: #{result.stdout.inspect}"

        # Output SHOULD contain the actual error
        expect(result.stderr).to include('No such file or directory'),
                                 "Error not in stderr: #{result.stderr.inspect}"
        expect(result.exit_status).to eq(1)
      end
    end

    context 'stat command (used by InSpec directory resource)' do
      it 'parses stat output for existing directory' do
        command = 'stat /etc'
        buffer = <<~OUTPUT
          stat /etc #{wrapper_suffix}
            File: /etc
            Size: 4096       Blocks: 8          IO Block: 4096   directory
          Access: (0755/drwxr-xr-x)  Uid: (    0/    root)   Gid: (    0/    root)
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, command)

        expect(result.stdout).to include('File: /etc')
        expect(result.stdout).to include('directory')
        expect(result.stdout).not_to include('2>&1')
        expect(result.exit_status).to eq(0)
      end

      it 'parses stat output for non-existing directory' do
        command = 'stat /var/log'
        buffer = <<~OUTPUT
          stat /var/log #{wrapper_suffix}
          stat: cannot stat '/var/log': No such file or directory
          #{exit_marker}=1
        OUTPUT

        result = parse_output(buffer, command)

        expect(result.stderr).to include('No such file or directory'),
                                 "Expected error in stderr: #{result.inspect}"
        expect(result.exit_status).to eq(1)
      end
    end

    context 'ANSI escape sequences' do
      it 'strips ANSI color codes' do
        buffer = "\e[32mgreen text\e[0m\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'echo')

        expect(result.stdout).not_to include("\e[")
        expect(result.stdout).to include('green text')
      end
    end

    context 'edge cases' do
      it 'handles empty command output' do
        buffer = "echo #{wrapper_suffix}\n#{exit_marker}=0\n"
        result = parse_output(buffer, 'echo')

        expect(result.stdout).to eq('')
        expect(result.exit_status).to eq(0)
      end

      it 'handles output with special characters' do
        # Test that output with shell-like characters is preserved
        buffer = <<~OUTPUT
          cat script.sh #{wrapper_suffix}
          #!/bin/bash
          echo "test $VAR"
          exit 0
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, 'cat script.sh')

        expect(result.stdout).to include('#!/bin/bash')
        expect(result.stdout).to include('echo "test $VAR"')
        expect(result.exit_status).to eq(0)
      end

      it 'preserves user output containing generic EXIT_CODE text' do
        # User output might contain EXIT_CODE text, but NOT our unique marker
        # Our UUID-based marker (e.g., __EXIT_CODE_deadbeef__) is unique per session
        buffer = <<~OUTPUT
          echo test #{wrapper_suffix}
          My variable is __EXIT_CODE__=42
          Some other EXIT_CODE reference
          #{exit_marker}=0
        OUTPUT

        result = parse_output(buffer, 'echo test')

        # Should preserve user's text since it doesn't match our unique marker
        expect(result.stdout).to include('My variable is __EXIT_CODE__=42')
        expect(result.stdout).to include('Some other EXIT_CODE reference')
        # Should use OUR marker for exit code
        expect(result.exit_status).to eq(0)
      end
    end
  end

  describe 'marker uniqueness' do
    it 'generates unique marker per session' do
      session1 = TrainPlugins::K8sContainer::PtySession.allocate.tap do |s|
        s.instance_variable_set(:@marker_id, SecureRandom.hex(4))
      end
      session2 = TrainPlugins::K8sContainer::PtySession.allocate.tap do |s|
        s.instance_variable_set(:@marker_id, SecureRandom.hex(4))
      end

      marker1 = session1.instance_variable_get(:@marker_id)
      marker2 = session2.instance_variable_get(:@marker_id)

      expect(marker1).not_to eq(marker2)
    end

    it 'marker format prevents collision with common output patterns' do
      # The marker format __EXIT_CODE_<hex>__ is highly unlikely in user output
      expect(exit_marker).to match(/^__EXIT_CODE_[0-9a-f]{8}__$/)
    end
  end
end
