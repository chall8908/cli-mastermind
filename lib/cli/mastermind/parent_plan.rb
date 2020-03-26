module CLI
  module Mastermind
    # Plan implementation designed to hold other plans forming the intermediate
    # nodes on the tree of loaded plans.
    # @private
    class ParentPlan
      extend Forwardable
      include Plan
      include Enumerable

      # Used in the interactive plan selector to display child plans
      attr_reader :children

      # @param (see Plan)
      # @see Plan
      def initialize(name, description=nil, filename=nil, &block)
        super

        @children = {}
      end

      # Get the child plan with the specified +name+.
      #
      # This method also checks plan aliases, so the given +name+ can also be a
      # plan's alias.
      #
      # @param name [String] the name of the child plan to retrieve
      # @return [Plan,nil] the child plan, if it exists
      def get_child(name)
        return @children[name] if @children.has_key? name
        @children.each_value.find { |child| child.aliases.include? name }
      end
      alias_method :[], :get_child
      alias_method :dig, :get_child

      # For Enumerable support
      def_delegators :@children, :each, :keep_if, :empty?

      # Adds new children to this plan
      #
      # @param plans [Array<Plan>] the plans to add
      # @return [Void]
      def add_children(plans)
        raise InvalidPlanError, 'Cannot add child plans to a plan with an action' unless @block.nil?
        plans.each(&method(:incorporate_plan))
      end

      # @return [Boolean] if this plan has any children
      def has_children?
        @children.any?
      end

      private

      # Adds a new plan to the children hash
      #
      # @param plan [Plan] the plan to add
      # @see resolve_conflicts
      def incorporate_plan(plan)
        @children[plan.name] = resolve_conflicts(plan.name, plan)
      end

      # Resolves plan name collisions.
      #
      # If two child plans have the same name, how they're resolved depends on
      # what kind of plan they are.  The following situations are convered by
      # this method:
      #
      # 1) Both plans have children.
      #   * In this case, the incoming plan's children are merged into the existing
      #     plan and the incoming plan is discarded.
      #
      # 2) One or both plans have no children.
      #   * In this case, it's assumed that the childless plans are executable.
      #     A warning is printed an the incoming plan replaces the existing plan.
      #
      # @param key [String] the key the incoming plan will be stored under
      # @param plan [Plan] the incoming plan
      # @return [Plan] the plan to store
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
