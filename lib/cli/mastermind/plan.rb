require 'forwardable'

module CLI
  module Mastermind
    class Plan
      extend Forwardable
      include UserInterface

      # The name of the plan.  Used to specify the plan from the command line
      # or from the interactive menu
      attr_reader :name

      # Displayed in the non-interactive list of available plans
      attr_reader :description

      # Used in the interactive plan selector to display child plans
      attr_reader :children

      # The file this plan was loaded from, if any
      attr_reader :filename

      # Loads a particular plan from the filesystem.
      # @see Loader
      def self.load(filename)
        ext = File.extname(filename)
        loader = Loader.find_loader(ext)
        loader.load(filename)
      end

      def initialize(name, description=nil, filename=nil, &block)
        @name = name.to_s.freeze
        @description = description.freeze
        @filename = filename
        @block = block
        @children = {}
      end

      # Get the child plan with the specified +name+
      def get_child(name)
        @children[name]
      end
      alias_method :[], :get_child
      alias_method :dig, :get_child

      def add_children(plans)
        raise InvalidPlanError, 'Cannot add child plans to a plan with an action' unless @block.nil?
        plans.each(&method(:incorporate_plan))
      end

      def has_children?
        @children.any?
      end

      def call(options=nil)
        case @block.arity
        when 1, -1 then instance_exec(options, &@block)
        else            instance_exec(&@block)
        end
      end

      private

      def incorporate_plan(plan)
        # If this namespace isn't taken just add the plan
        if @children.has_key? plan.name

          # Otherwise, we need to handle a name collision
          existing_plan = @children[plan.name]

          # If both plans have children, we merge them together
          if existing_plan.has_children? and plan.has_children?
            existing_plan.add_children plan.children.values

            return existing_plan
          end

          # Otherwise, the plan defined later wins and overwrites the existing plan
          warn <<~PLAN_COLLISON.strip
                 Plan name collision encountered when loading plans from "#{plan.filename}" that cannot be merged.
                 "#{plan.name}" was previously defined in "#{existing_plan.filename}".
                 Plans from "#{plan.filename}" will be used instead.
               PLAN_COLLISON
        end

        @children[plan.name] = plan
      end

      # Delegate configuration to the top-level configuration object
      def_delegator :'CLI::Mastermind', :configuration
      alias_method :config, :configuration
    end
  end
end
