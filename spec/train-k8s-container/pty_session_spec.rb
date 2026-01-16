# frozen_string_literal: true

require_relative '../spec_helper'
require 'train-k8s-container/pty_session'

RSpec.describe TrainPlugins::K8sContainer::PtySession do
  let(:session_key) { 'default/test-pod/test-container' }
  let(:kubectl_cmd) { 'kubectl exec --stdin test-pod -n default -c test-container' }
  let(:logger) { Logger.new(IO::NULL) }
  let(:session) do
    described_class.new(
      session_key: session_key,
      kubectl_cmd: kubectl_cmd,
      shell: '/bin/bash',
      timeout: 300,
      logger: logger
    )
  end

  describe '#initialize' do
    it 'sets session_key' do
      expect(session.session_key).to eq(session_key)
    end

    it 'defaults to bash shell' do
      session_without_shell = described_class.new(
        session_key: session_key,
        kubectl_cmd: kubectl_cmd
      )
      expect(session_without_shell.instance_variable_get(:@shell)).to eq('/bin/bash')
    end

    it 'accepts custom shell' do
      session_with_sh = described_class.new(
        session_key: session_key,
        kubectl_cmd: kubectl_cmd,
        shell: '/bin/sh'
      )
      expect(session_with_sh.instance_variable_get(:@shell)).to eq('/bin/sh')
    end

    it 'starts disconnected' do
      expect(session.connected?).to be_falsey
    end
  end

  describe '#connect' do
    it 'establishes PTY connection' do
      # Mock PTY.spawn
      mock_reader = double('reader', closed?: false)
      mock_writer = double('writer', closed?: false)
      allow(mock_writer).to receive(:sync=)
      mock_pid = 12_345

      allow(PTY).to receive(:spawn).with("#{kubectl_cmd} -- /bin/bash")
                                   .and_return([mock_reader, mock_writer, mock_pid])
      allow(session).to receive(:sleep)

      session.connect

      expect(session.reader).to eq(mock_reader)
      expect(session.writer).to eq(mock_writer)
      expect(session.pid).to eq(mock_pid)
      expect(session.connected?).to be true
    end

    it 'raises PtyError if already connected (wraps SessionClosedError)' do
      mock_reader = double('reader', closed?: false, close: true)
      mock_writer = double('writer', closed?: false, close: true)
      allow(mock_writer).to receive(:sync=).and_return(true)
      allow(mock_writer).to receive(:puts)

      allow(PTY).to receive(:spawn).and_return([mock_reader, mock_writer, 12_345])
      allow(session).to receive(:sleep)
      allow(Process).to receive(:wait)

      session.connect

      expect do
        session.connect
      end.to raise_error(TrainPlugins::K8sContainer::PtySession::PtyError, /Failed to connect.*already connected/)
    end

    it 'raises PtyError on PTY.spawn failure' do
      allow(PTY).to receive(:spawn).and_raise(Errno::ENOENT, 'kubectl not found')

      expect do
        session.connect
      end.to raise_error(TrainPlugins::K8sContainer::PtySession::PtyError, /Failed to connect/)
    end

    it 'cleans up on connection failure' do
      allow(PTY).to receive(:spawn).and_raise(StandardError, 'spawn failed')

      expect(session).to receive(:cleanup)

      expect do
        session.connect
      end.to raise_error(TrainPlugins::K8sContainer::PtySession::PtyError)
    end
  end

  describe '#connected?' do
    it 'returns false when reader is nil' do
      expect(session.connected?).to be_falsey
    end

    it 'returns false when writer is nil' do
      session.instance_variable_set(:@reader, double('reader'))
      expect(session.connected?).to be_falsey
    end

    it 'returns false when reader is closed' do
      session.instance_variable_set(:@reader, double('reader', closed?: true))
      session.instance_variable_set(:@writer, double('writer', closed?: false))
      expect(session.connected?).to be false
    end

    it 'returns false when writer is closed' do
      session.instance_variable_set(:@reader, double('reader', closed?: false))
      session.instance_variable_set(:@writer, double('writer', closed?: true))
      expect(session.connected?).to be false
    end

    it 'returns true when both reader and writer are open' do
      session.instance_variable_set(:@reader, double('reader', closed?: false))
      session.instance_variable_set(:@writer, double('writer', closed?: false))
      expect(session.connected?).to be true
    end
  end

  describe '#healthy?' do
    it 'returns false when not connected' do
      expect(session.healthy?).to be false
    end

    it 'returns true when connected and process is alive' do
      session.instance_variable_set(:@reader, double('reader', closed?: false))
      session.instance_variable_set(:@writer, double('writer', closed?: false))
      session.instance_variable_set(:@pid, 12_345)

      allow(Process).to receive(:kill).with(0, 12_345).and_return(1)

      expect(session.healthy?).to be true
    end

    it 'returns false when process is dead' do
      session.instance_variable_set(:@reader, double('reader', closed?: false))
      session.instance_variable_set(:@writer, double('writer', closed?: false))
      session.instance_variable_set(:@pid, 12_345)

      allow(Process).to receive(:kill).with(0, 12_345).and_raise(Errno::ESRCH)

      expect(session.healthy?).to be false
    end
  end

  describe '#cleanup' do
    it 'closes reader and writer and waits for process' do
      mock_reader = double('reader', close: true, closed?: false)
      mock_writer = double('writer', close: true, closed?: false, puts: true)
      mock_pid = 12_345

      session.instance_variable_set(:@reader, mock_reader)
      session.instance_variable_set(:@writer, mock_writer)
      session.instance_variable_set(:@pid, mock_pid)

      expect(mock_writer).to receive(:puts).with('exit')
      expect(mock_writer).to receive(:close)
      expect(mock_reader).to receive(:close)
      expect(Process).to receive(:wait).with(mock_pid, Process::WNOHANG)

      session.cleanup
    end

    it 'handles cleanup errors gracefully' do
      mock_reader = double('reader')
      allow(mock_reader).to receive(:close).and_raise(IOError, 'already closed')

      session.instance_variable_set(:@reader, mock_reader)

      expect { session.cleanup }.not_to raise_error
    end

    it 'handles nil reader/writer' do
      expect { session.cleanup }.not_to raise_error
    end
  end

  describe '#parse_output (private method)' do
    # Helper to get the session's unique exit marker
    let(:exit_marker) { session.send(:exit_marker) }
    let(:wrapper_suffix) { session.send(:wrapper_suffix) }

    it 'parses successful command output' do
      buffer = "whoami\nroot\n#{exit_marker}=0\n"
      result = session.send(:parse_output, buffer, 'whoami')

      expect(result.stdout).to eq('root')
      expect(result.stderr).to eq('')
      expect(result.exit_status).to eq(0)
    end

    it 'parses failed command output' do
      buffer = "invalid-command\nbash: invalid-command: command not found\n#{exit_marker}=127\n"
      result = session.send(:parse_output, buffer, 'invalid-command')

      expect(result.stdout).to eq('')
      expect(result.stderr).to include('command not found')
      expect(result.exit_status).to eq(127)
    end

    it 'removes command echo from output' do
      command = 'echo test'
      buffer = "#{command}\ntest\n#{exit_marker}=0\n"
      result = session.send(:parse_output, buffer, command)

      expect(result.stdout).to eq('test')
      expect(result.stdout).not_to include('echo test')
    end

    it 'removes command wrapper from output' do
      command = 'whoami'
      buffer = "#{command} #{wrapper_suffix}\nroot\n#{exit_marker}=0\n"
      result = session.send(:parse_output, buffer, command)

      expect(result.stdout).to eq('root')
      expect(result.stdout).not_to include('2>&1')
      expect(result.stdout).not_to include(exit_marker)
    end

    it 'handles output with ANSI sequences' do
      buffer = "\e[31mError:\e[0m Something failed\n#{exit_marker}=1\n"
      result = session.send(:parse_output, buffer, 'test-command')

      expect(result.stderr).not_to include("\e[31m")
      expect(result.stderr).to include('Error: Something failed')
    end

    it 'handles multi-line output' do
      buffer = "ls\nfile1.txt\nfile2.txt\nfile3.txt\n#{exit_marker}=0\n"
      result = session.send(:parse_output, buffer, 'ls')

      expect(result.stdout).to include('file1.txt')
      expect(result.stdout).to include('file2.txt')
      expect(result.stdout).to include('file3.txt')
    end

    it 'defaults to exit code 1 if marker not found' do
      buffer = "some output without exit marker\n"
      result = session.send(:parse_output, buffer, 'test')

      expect(result.exit_status).to eq(1)
    end

    it 'generates unique marker_id on initialization' do
      expect(session.marker_id).to match(/^[0-9a-f]{8}$/)
    end
  end

  describe 'constants' do
    it 'defines DEFAULT_COMMAND_TIMEOUT' do
      expect(described_class::DEFAULT_COMMAND_TIMEOUT).to eq(60)
    end

    it 'defines DEFAULT_SESSION_TIMEOUT' do
      expect(described_class::DEFAULT_SESSION_TIMEOUT).to eq(300)
    end
  end

  describe 'error classes' do
    it 'defines PtyError' do
      expect(described_class::PtyError.ancestors).to include(TrainPlugins::K8sContainer::K8sContainerError)
    end

    it 'defines SessionClosedError' do
      expect(described_class::SessionClosedError.ancestors).to include(described_class::PtyError)
    end

    it 'defines CommandTimeoutError' do
      expect(described_class::CommandTimeoutError.ancestors).to include(described_class::PtyError)
    end
  end
end
