# frozen_string_literal: true

module Train
  module K8s
    module Container
      module Platform
        PLATFORM_NAME = "k8s-container"

        def platform
          Train::Platforms.name(PLATFORM_NAME).in_family("unix")
          force_platform!(PLATFORM_NAME, release: Train::K8s::Container::VERSION)
        end
      end
    end
  end
end
