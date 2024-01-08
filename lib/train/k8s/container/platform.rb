# frozen_string_literal: true

module Train
  module K8s
    module Container
      module Platform

        def platform
          Train::Platforms.name("k8s").in_family("cloud")
          force_platform!("k8s_container", release: Train::K8s::Container::VERSION)
        end
      end
    end
  end
end
