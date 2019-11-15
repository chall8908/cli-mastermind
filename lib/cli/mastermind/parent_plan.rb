module CLI
  module Mastermind
    class ParentPlan
      extend Forwardable
      include Plan
      include Enumerable

      # Used in the interactive plan selector to display child plans
      attr_reader :children

      def initialize(name, description=nil, filename=nil, &block)
        super

        @children = {}
      end

      # Get the child plan with the specified +name+
      def get_child(name)
        return @children[name] if @children.has_key? name
        @children.each_value.find { |child| child.aliases.include? name }
      end
      alias_method :[], :get_child
      alias_method :dig, :get_child

      def_delegators :@children, :each, :keep_if, :empty?

      def add_children(plans)
        raise InvalidPlanError, 'Cannot add child plans to a plan with an action' unless @block.nil?
        plans.each(&method(:incorporate_plan))
      end

      def has_children?
        @children.any?
      end

      private

      def incorporate_plan(plan)
        @children[plan.name] = resolve_conflicts(plan.name, plan)
      end

      def resolve_conflicts(key, plan)
        # If this namespace isn't taken we're good
        return plan unless @children.has_key?(key)

        # Otherwise, we need to handle a name collision
        existing_plan = @children[key]

        # If both plans have children, we merge them together
        if existing_plan.has_children? and plan.has_children?
          existing_plan.add_children plan.children.values

          return existing_plan
        end

        # Otherwise, the plan defined later wins and overwrites the existing plan

        # Warn the user that this is happening, unless we're running tests.
        warn <<~PLAN_COLLISON.strip unless defined? RSpec
               Plan name collision encountered when loading plans from "#{plan.filename}" that cannot be merged.
               "#{key}" was previously defined in "#{existing_plan.filename}".
               Plan "#{key}" from "#{plan.filename}" will be used instead.
             PLAN_COLLISON

        plan
      end
    end
  end
end
