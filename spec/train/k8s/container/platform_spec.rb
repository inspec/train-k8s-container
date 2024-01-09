# frozen_string_literal: true

RSpec.describe Train::K8s::Container::Platform do
  it "its platform name should be `k8s_container`" do
    expect(train.connection.platform.name).to eq(Train::K8s::Container::Platform::PLATFORM_NAME)
  end

  it "its platform family should be `cloud`" do
    expect(train.connection.platform.family).to eq("os")
  end
end

