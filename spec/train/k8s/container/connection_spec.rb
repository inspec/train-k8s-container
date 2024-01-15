# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Connection do
  let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "default" } }

  subject { described_class.new(options) }

  it "it executes a connect" do
    expect { subject }.not_to raise_error
  end

  context "when options are not present" do
    context "when pod parameter is missing" do
      let(:options) { { container_name: "nginx" } }
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

    it "should raise Connection error from server" do
      expect { subject }.to raise_error(Train::K8s::Container::ConnectionError)
        .with_message(/Error from server/)
    end
  end
end

