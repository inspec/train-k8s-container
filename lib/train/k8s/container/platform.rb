# frozen_string_literal: true

module Train
  module K8s
    module Container
      class Platform

        def platform
          Train::Platforms.name('k8s').in_family('cloud')
        end
      end
    end
  end
end
