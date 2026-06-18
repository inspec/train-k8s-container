# frozen_string_literal: true
require_relative "spec_helper"

RSpec.describe TrainPlugins::K8sContainer do
  it "has a version number" do
    expect(TrainPlugins::K8sContainer::VERSION).not_to be nil
  end
end
