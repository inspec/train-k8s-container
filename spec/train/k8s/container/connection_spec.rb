# frozen_string_literal: true
RSpec.describe Train::K8s::Container::Connection do
  it "it executes a connect" do
    expect(train.connection.connect).not_to be nil
  end
end

