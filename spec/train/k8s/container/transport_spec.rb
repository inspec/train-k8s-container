# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Transport do
  let(:platform_name) { Train::K8s::Container::Platform::PLATFORM_NAME }
  let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "default" } }
  let(:kube_client) { double(Train::K8s::Container::KubectlExecClient) }
  let(:shell_op) { Train::Extras::CommandResult.new(stdout, stderr, exitstatus) }

  describe ".name" do
    it "registers the transport aginst the platform" do
      expect(Train::Plugins.registry[platform_name]).to eq(described_class)
    end
  end

  let(:stdout) { "Linux\n" }
  let(:stderr) { "" }
  let(:exitstatus) { 0 }
  before do
    allow(Train::K8s::Container::KubectlExecClient).to receive(:new).with(**options).and_return(kube_client)
    allow(kube_client).to receive(:execute).with("uname").and_return(shell_op)
  end

  subject { described_class.new(options) }
  describe "#options" do
    it "sets the options" do
      expect(subject.options).to include(options)
    end
  end

  describe "#connection" do
    it "should return the connection object" do
      expect(subject.connection).to be_a(Train::K8s::Container::Connection)
    end
  end

end


