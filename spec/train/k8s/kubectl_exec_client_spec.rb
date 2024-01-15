# frozen_string_literal: true
require_relative "../../spec_helper"

RSpec.describe Train::K8s::Container::KubectlExecClient do
  let(:shell) { double(Mixlib::ShellOut) }
  let(:pod) { "shell-demo" }
  let(:container_name) { "nginx" }
  let(:namespace) { Train::K8s::Container::KubectlExecClient::DEFAULT_NAMESPACE }
  let(:shell_op) { Struct.new(:stdout, :stderr, :exitstatus) }

  subject { described_class.new(pod: pod, namespace: namespace, container_name: container_name) }
  describe ".instance" do
    it "should return a kubectl exec object" do
      expect(subject.pod).to eq(pod)
      expect(subject.namespace).to eq(namespace)
      expect(subject.container_name).to eq(container_name)
    end
  end

  describe "#execute" do
    let(:result) { shell_op.new(stdout, stderr, exitstatus) }
    before do
      allow(Mixlib::ShellOut).to receive(:new).and_return(shell)
      allow(shell).to receive(:run_command).and_return(result)
    end

    subject { described_class.new(pod: pod, namespace: namespace, container_name: container_name).execute(command) }
    context "on successful command" do
      let(:stdout) { "root" }
      let(:stderr) { "" }
      let(:exitstatus) { 0 }
      let(:command) { "whoami" }
      it "#stdout returns the output of the given command" do
        expect(subject.stdout).to eq("root")
      end

      it "#stderr returns empty" do
        expect(subject.stderr).to be_empty
      end

      it "#exit_status returns zero exit code" do
        expect(subject.exit_status).to eq(0)
      end
    end

    context "on wrong command" do
      let(:stdout) { "" }
      let(:stderr) { "chmod: missing operand\nTry 'chmod --help' for more information.\ncommand terminated with exit code 1\n" }
      let(:exitstatus) { 1 }
      let(:command) { "chmod" }
      it "#stdout returns empty" do
        expect(subject.stdout).to be_empty
      end

      it "#stderr returns error message" do
        expect(subject.stderr).not_to be_empty
      end

      it "#exit_status returns non-zero exit code" do
        expect(subject.exit_status).not_to eq(0)
      end
    end
  end
end