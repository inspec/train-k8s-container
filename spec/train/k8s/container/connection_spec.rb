# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Connection do
  let(:options) { { pod: "shell-demo", container_name: "nginx", namespace: "default" } }

  subject { described_class.new(options) }

  it "it executes a connect" do
    expect(subject.connect).to be(true)
  end
end

