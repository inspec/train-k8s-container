module TrainPlugins::K8sContainer
  # Since we're mixing in the platform detection facility into Connection,
  # this has to come in as a Module.
  module Platform
    # The method `platform` is called when platform detection is
    # about to be performed.  Train core defines a sophisticated
    # system for platform detection, but for most plugins, you'll
    # only ever run on the special platform for which you are targeting.
    def platform
      Train::Platforms.name("os").in_family("unix")
      #@force_platform!("os", release: TrainPlugins::K8sContainer::VERSION)
    end
  end
end