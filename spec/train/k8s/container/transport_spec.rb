# frozen_string_literal: true
require_relative "../../../spec_helper"

RSpec.describe Train::K8s::Container::Transport do
  it "transport should not be nil" do
    expect(train).not_to be nil
  end
end


