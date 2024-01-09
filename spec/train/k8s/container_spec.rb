# frozen_string_literal: true
require_relative "../../spec_helper"

RSpec.describe Train::K8s::Container do
  it "has a version number" do
    expect(Train::K8s::Container::VERSION).not_to be nil
  end
end
