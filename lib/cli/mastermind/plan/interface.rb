module CLI::Mastermind
  class Plan
    # The plan interface is everything that is required in order for an object
    # to be usable as a plan.
    #
    # Objects adhering to this interface must implement their own +call+ method.
    # This method is what is invoked by Mastermind to execute a plan.
    #
    # Mastermind assumes that any plan it encounters could have children, hence
    # the +has_children?+ method here.  Since the default PlanfileLoader doesn't
    # permit custom plan classes when defining a plan with children, it's assumed
    # that any custom plans (which include this interface) won't have any children
    # at all.
    module Interface
      extend Forwardable

      def self.included(base)
        # The name of the plan.  Used to specify the plan from the command line
        # or from the interactive menu
        base.attr_reader :name

        # Displayed in the non-interactive list of available plans
        base.attr_reader :description

        # The file this plan was loaded from, if any
        base.attr_reader :filename
      end

      def initialize(name, description=nil, filename=nil, &block)
        @name = name.to_s.freeze
        @description = description.freeze
        @filename = filename
        @block = block
      end

      def has_children?
        false
      end

      def call(options=nil)
        raise NotImplementedError
      end

      # Delegate configuration to the top-level configuration object
      def_delegator :'CLI::Mastermind', :configuration
      alias_method :config, :configuration
    end
  end
end
