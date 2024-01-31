# frozen_string_literal: true
require_relative "../../../spec_helper"

class TestConnection < Train::Plugins::Transport::BaseConnection
  include Train::K8s::Container::Platform
end

RSpec.describe Train::K8s::Container::Platform do

  subject { TestConnection.new }
  it "its platform name should be `k8s-container`" do
    expect(subject.platform.name).to eq(Train::K8s::Container::Platform::PLATFORM_NAME)
  end

  it "its platform family should be `os`" do
    expect(subject.platform.family).to eq("unix")
  end
end

