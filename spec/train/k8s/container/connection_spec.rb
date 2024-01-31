# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Connection do
  let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "default" } }
  let(:kube_client) { double(Train::K8s::Container::KubectlExecClient) }
  let(:shell_op) { Train::Extras::CommandResult.new(stdout, stderr, exitstatus) }

  subject { described_class.new(options) }
  let(:stdout) { "Linux\n" }
  let(:stderr) { "" }
  let(:exitstatus) { 0 }
  before do
    allow(Train::K8s::Container::KubectlExecClient).to receive(:new).with(**options).and_return(kube_client)
    allow(kube_client).to receive(:execute).with("uname").and_return(shell_op)
  end

  it "it executes a connect" do
    expect { subject }.not_to raise_error
  end

  context "when options are not present" do
    context "when pod parameter is missing" do
      let(:options) { { pod: nil, container_name: "nginx" } }
      it "should raise error for missing Pod" do
        expect { subject }.to raise_error(ArgumentError).with_message("Missing Parameter `pod`")
      end
    end

    context "when container_name paramete is missing" do
      let(:options) { { pod: "shell-demo" } }
      it "should raise error for missing Container Name" do
        expect { subject }.to raise_error(ArgumentError).with_message("Missing Parameter `container_name`")
      end
    end
  end

  context "when there is a server error" do
    let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "de" } }
    let(:stdout) { "" }
    let(:stderr) { "Error from server (NotFound): namespaces \"de\" not found\n" }
    let(:exitstatus) { 1 }

    it "should raise Connection error from server" do
      expect { subject }.to raise_error(Train::K8s::Container::ConnectionError)
        .with_message(/Error from server/)
    end
  end

  describe "#file" do
    let(:proc_version) { "Linux version 6.5.11-linuxkit (root@buildkitsandbox) (gcc (Alpine 12.2.1_git20220924-r10) 12.2.1 20220924, GNU ld (GNU Binutils) 2.40) #1 SMP PREEMPT Wed Dec  6 17:08:31 UTC 2023\n" }
    let(:stdout) { proc_version }
    before do
      allow(kube_client).to receive(:execute).with("cat /proc/version || echo -n").and_return(shell_op)
    end
    it "executes a file connection" do
      expect(subject.file("/proc/version").content).to eq(stdout)
    end
  end
end

