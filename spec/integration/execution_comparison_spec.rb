# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container'

RSpec.describe 'Execution Path Comparison', type: :integration do
  before(:all) do
    skip_if_no_integration_env
  end

  after(:each) do
    TrainPlugins::K8sContainer::SessionManager.instance.cleanup_all
  end

  let(:pod) { 'test-ubuntu' }
  let(:container) { 'test-ubuntu' }
  let(:namespace) { 'default' }

  let(:pty_client) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: pod,
      namespace: namespace,
      container_name: container,
      use_pty: true
    )
  end

  let(:oneoff_client) do
    TrainPlugins::K8sContainer::KubectlExecClient.new(
      pod: pod,
      namespace: namespace,
      container_name: container,
      use_pty: false
    )
  end

  describe 'Simple commands should have identical results' do
    %w[
      whoami
      pwd
      hostname
    ].each do |cmd|
      it "executes '#{cmd}' identically on both paths" do
        pty_result = pty_client.execute(cmd)
        oneoff_result = oneoff_client.execute(cmd)

        expect(pty_result.exit_status).to eq(oneoff_result.exit_status),
                                          "Exit status mismatch for '#{cmd}': PTY=#{pty_result.exit_status}, " \
                                          "OneOff=#{oneoff_result.exit_status}"
        expect(pty_result.stdout.strip).to eq(oneoff_result.stdout.strip),
                                           "Stdout mismatch for '#{cmd}':\n  " \
                                           "PTY: #{pty_result.stdout.inspect}\n  " \
                                           "OneOff: #{oneoff_result.stdout.inspect}"
      end
    end
  end

  describe 'File stat commands (used by InSpec directory resource)' do
    it 'checks existing directory /etc' do
      # This is the type of command Train runs for directory.exist?
      cmd = 'stat /etc 2>/dev/null && echo EXISTS || echo NOT_FOUND'

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      expect(pty_result.exit_status).to eq(oneoff_result.exit_status)
      expect(pty_result.stdout).to include('EXISTS')
      expect(oneoff_result.stdout).to include('EXISTS')
    end

    it 'checks non-existing directory /nonexistent' do
      cmd = 'stat /nonexistent 2>/dev/null && echo EXISTS || echo NOT_FOUND'

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      expect(pty_result.exit_status).to eq(oneoff_result.exit_status)
      expect(pty_result.stdout).to include('NOT_FOUND')
      expect(oneoff_result.stdout).to include('NOT_FOUND')
    end

    it 'checks /var/log directory (the problematic one from bug report)' do
      cmd = 'stat /var/log 2>/dev/null && echo EXISTS || echo NOT_FOUND'

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      expect(pty_result.exit_status).to eq(oneoff_result.exit_status),
                                        "Exit status mismatch: PTY=#{pty_result.exit_status}, OneOff=#{oneoff_result.exit_status}"

      # Both should agree on whether /var/log exists
      pty_exists = pty_result.stdout.include?('EXISTS')
      oneoff_exists = oneoff_result.stdout.include?('EXISTS')
      expect(pty_exists).to eq(oneoff_exists),
                            "Existence detection mismatch for /var/log:\n  " \
                            "PTY stdout: #{pty_result.stdout.inspect}\n  " \
                            "OneOff stdout: #{oneoff_result.stdout.inspect}"
    end

    it 'checks ownership of /etc (file owner detection)' do
      cmd = 'stat -c "%U" /etc 2>/dev/null'

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      expect(pty_result.exit_status).to eq(oneoff_result.exit_status)
      expect(pty_result.stdout.strip).to eq(oneoff_result.stdout.strip),
                                         "Owner mismatch for /etc:\n  PTY: #{pty_result.stdout.inspect}\n  OneOff: #{oneoff_result.stdout.inspect}"
    end
  end

  describe 'Multi-line command output parsing' do
    it 'handles simple multi-line output' do
      cmd = "echo -e 'line1\\nline2\\nline3'"

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      expect(pty_result.stdout.lines.count).to eq(oneoff_result.stdout.lines.count),
                                               "Line count mismatch:\n  " \
                                               "PTY (#{pty_result.stdout.lines.count} lines): #{pty_result.stdout.inspect}\n  " \
                                               "OneOff (#{oneoff_result.stdout.lines.count} lines): #{oneoff_result.stdout.inspect}"
    end

    it 'handles ls output correctly' do
      cmd = 'ls -la /etc | head -5'

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      # Both should have similar number of lines (allowing for minor differences)
      expect(pty_result.stdout.lines.count).to be_within(1).of(oneoff_result.stdout.lines.count)
    end
  end

  describe 'Multi-line command INPUT (the problematic case from bug report)' do
    it 'handles for loop command' do
      # This is similar to the certificate check that showed the bug
      cmd = <<~SHELL.strip
        for f in /etc/*.conf; do
          echo "Found: $f"
        done
      SHELL

      pty_result = pty_client.execute(cmd)
      oneoff_result = oneoff_client.execute(cmd)

      # The key test: PTY output should NOT contain the command itself
      expect(pty_result.stdout).not_to include('for f in'),
                                       "PTY output contains command echo-back: #{pty_result.stdout.inspect}"

      expect(pty_result.exit_status).to eq(oneoff_result.exit_status)
    end

    it 'does not include command wrapper in output' do
      cmd = 'echo test'

      pty_result = pty_client.execute(cmd)

      # Output should not contain our internal marker wrapper
      expect(pty_result.stdout).not_to include('__EXIT_CODE__'),
                                       "PTY output contains marker: #{pty_result.stdout.inspect}"
      expect(pty_result.stdout).not_to include('2>&1'),
                                       "PTY output contains wrapper: #{pty_result.stdout.inspect}"
    end
  end

  describe 'Exit code handling' do
    it 'returns correct exit code for successful command' do
      pty_result = pty_client.execute('true')
      oneoff_result = oneoff_client.execute('true')

      expect(pty_result.exit_status).to eq(0)
      expect(oneoff_result.exit_status).to eq(0)
    end

    it 'returns correct exit code for failed command' do
      pty_result = pty_client.execute('false')
      oneoff_result = oneoff_client.execute('false')

      expect(pty_result.exit_status).to eq(1)
      expect(oneoff_result.exit_status).to eq(1)
    end

    it 'returns correct exit code for non-existent command' do
      pty_result = pty_client.execute('nonexistent_command_12345')
      oneoff_result = oneoff_client.execute('nonexistent_command_12345')

      expect(pty_result.exit_status).not_to eq(0)
      expect(oneoff_result.exit_status).not_to eq(0)
    end
  end

  describe 'Train Connection file operations comparison' do
    let(:pty_conn) do
      # Create connection that will use PTY mode (default)
      TrainPlugins::K8sContainer::Connection.new(
        pod: pod,
        container_name: container,
        namespace: namespace
      )
    end

    it 'correctly detects existing file /etc/passwd' do
      file = pty_conn.file('/etc/passwd')
      expect(file.exist?).to be true
    end

    it 'correctly detects non-existing file' do
      file = pty_conn.file('/this/does/not/exist')
      expect(file.exist?).to be false
    end

    it 'correctly detects /var/log existence' do
      file = pty_conn.file('/var/log')
      actual_exists = file.exist?

      # Run raw command to verify
      raw_result = pty_conn.run_command('test -d /var/log && echo YES || echo NO')
      expected_exists = raw_result.stdout.strip == 'YES'

      expect(actual_exists).to eq(expected_exists),
                               "File.exist? returned #{actual_exists} but raw command says #{expected_exists}"
    end
  end
end
