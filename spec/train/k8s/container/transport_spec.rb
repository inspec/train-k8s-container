# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Transport do
  let(:platform_name) { Train::K8s::Container::Platform::PLATFORM_NAME }
  let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "default" } }

  describe ".name" do
    it "registers the transport aginst the platform" do
      expect(Train::Plugins.registry[platform_name]).to eq(described_class)
    end
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


