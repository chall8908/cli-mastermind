module CLI::Mastermind
  class Loader
    # Loader implementation to handle the default .plan format
    # @private
    class PlanfileLoader < Loader
      @loadable_extensions = %w[ .plan ].freeze

      def self.load(filename)
        DSL.new(filename).plans
      end

      class InvalidPlanfileError < Error
      end

      private

      class DSL
        extend Forwardable

        # @return [Array<Plan>] the plans defined by the loaded file or block
        attr_reader :plans

        # Loads and evaluates a local file or a given block.
        #
        # If given both, the block takes priority.
        #
        # @example DSL.new('path/to/file.plan')
        # @example DSL.new { ...methods go here... }
        # @param filename [String,nil] the name of the file that contains this plan
        # @param block [#call,nil] a block to evaluate
        def initialize(filename=nil, &block)
          @plans = []
          @filename = filename

          if block_given?
            instance_eval(&block)
          elsif File.exists? filename
            instance_eval(File.read(filename), filename, 0)
          else
            raise InvalidPlanfileError, 'Must provide valid path to a planfile or a block'
          end
        end

        # Describes a ParentPlan
        #
        # @param name [String] the name of the plan
        # @param block [#call] passed to a new DSL object to define more plans
        def plot(name, &block)
          plan = ParentPlan.new name, @description, @filename
          @description = nil
          @plans << plan
          plan.add_children DSL.new(@filename, &block).plans
        end
        alias_method :namespace, :plot

        # @param text [String] the description of the next plan
        def description(text)
          @description = text
        end
        alias_method :desc, :description

        # Defines an executable plan
        #
        # @param name [String] the name of the plan
        # @param plan_class [Plan] the plan class
        # @param block [#call] passed into the newly created plan
        # @return [void]
        def plan(name, plan_class = ExecutablePlan, &block)
          @plans << plan_class.new(name, @description, @filename, &block)
          @description = nil
        end
        alias_method :task, :plan

        # Sets an alias on the previously created plan
        #
        # @param alias_to [String] the alias to add
        def set_alias(alias_to)
          @plans.last.add_alias(alias_to)
        end

        # Delegate configuration to the top-level configuration object
        # Planfile loading happens well after configuration has been loaded. So,
        # we can safely rely on it being setup at this point.
        def_delegator :'CLI::Mastermind', :configuration
        alias_method :config, :configuration
      end
    end
  end
end
