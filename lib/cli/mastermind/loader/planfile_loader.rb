module CLI::Mastermind
  class Loader
    class PlanfileLoader < Loader
      @loadable_extensions = %w[ .plan ].freeze

      def self.load(filename)
        DSL.new(filename).plans
      end

      private

      class DSL
        attr_reader :plans

        def initialize(filename=nil, &block)
          @plans = []

          if block_given?
            instance_eval(&block)
          elsif File.exists? filename
            instance_eval(File.read(filename), filename, 0)
          else
            raise 'Must provide valid path to a planfile or a block', Error
          end
        end

        def plot(name, &block)
          plan = Plan.new name, @description
          @description = nil
          @plans << plan
          plan.add_children DSL.new(&block).plans
        end
        alias_method :namespace, :plot

        def description(text)
          @description = text
        end
        alias_method :desc, :description

        def plan(name, &block)
          @plans << Plan.new(name, @description, &block)
          @description = nil
        end
        alias_method :task, :plan
      end
    end
  end
end
