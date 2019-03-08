module CLI::Mastermind
  class Loader
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

        attr_reader :plans

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

        def plot(name, &block)
          plan = Plan.new name, @description, @filename
          @description = nil
          @plans << plan
          plan.add_children DSL.new(@filename, &block).plans
        end
        alias_method :namespace, :plot

        def description(text)
          @description = text
        end
        alias_method :desc, :description

        def plan(name, plan_class = Plan, &block)
          @plans << plan_class.new(name, @description, @filename, &block)
          @description = nil
        end
        alias_method :task, :plan

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
