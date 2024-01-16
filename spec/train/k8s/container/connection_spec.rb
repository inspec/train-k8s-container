# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Connection do
  let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "default" } }
  let(:kube_client) { Train::K8s::Container::KubectlExecClient.new(**options) }
  let(:struct) { Struct.new(:stdout, :stderr, :exitstatus) }
  let(:shell_op) { struct.new(stdout, stderr, exitstatus) }

  subject { described_class.new(options) }
  let(:stdout) { "Linux\n" }
  let(:stderr) { "" }
  let(:exitstatus) { 0 }
  before do
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
end

