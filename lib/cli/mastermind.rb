# coding: utf-8
require 'forwardable'
require 'pathname'
require 'cli/ui'
require 'cli/mastermind/arg_parse'
require 'cli/mastermind/configuration'
require 'cli/mastermind/errors'
require 'cli/mastermind/user_interface'
require 'cli/mastermind/loader'
require 'cli/mastermind/plan'
require 'cli/mastermind/parent_plan'
require 'cli/mastermind/executable_plan'
require 'cli/mastermind/version'

module CLI
  # The main Mastermind module handles initial setup, user interaction, and final plan execution
  module Mastermind
    extend UserInterface

    class << self
      # Lazy-load configuration object
      #
      # @return [Configuration] the loaded configuration
      def configuration
        @config ||= spinner('Loading configuration') do
          Configuration.new(@base_path).tap do |config|

            # Load any autoloads
            if @autoloads && @autoloads.any?
              @autoloads.each { |masterplan| config.load_masterplan masterplan }
            end
          end
        end
      end

      # Allows utilities wrapping Mastermind to specify that only plans under a
      # particular path should be loaded.
      #
      # @param base_path [String] the path to the planfiles that should be loaded
      # @return [Void]
      def base_path=(base_path)
        @base_path = base_path
      end

      # Allows utilities wrapping Mastermind to specify a top level plan without
      # having to monkey with the incomming arguments.
      #
      # @param base_plan [String] the top-level plan that should be automatically selected
      # @return [Void]
      def base_plan=(base_plan)
        @base_plan = base_plan
      end

      # Convenience method for ArgParse.add_option
      #
      # @see ArgParse.add_option
      #
      # @param args arguments passed directly to OptionParser#on
      # @param block [Proc] block passed as the handler for the above arguments
      # @return [Void]
      def add_argument(*args, &block)
        ArgParse.add_option(*args, &block)
      end

      # Allows utilities wrapping Mastermind to specify masterplans that should be
      # automatically loaded.  Masterplans loaded this way are loaded _after_ all
      # others and so should only be used to set default values.
      #
      # Adding a new autoload after configuration has been initialized will
      # immediately load the new masterplan.
      #
      # @param masterplan_path [String] the path to the masterplan to load
      # @return [Void]
      def autoload_masterplan(masterplan_path)
        path = Pathname.new masterplan_path
        raise Error, "`#{masterplan_path}` is not an absolute path" unless path.absolute?
        raise Error, "`#{masterplan_path}` does not exist or is not a file" unless path.file?
        @autoloads ||= []
        @autoloads << masterplan_path

        # Don't use configuration method here to avoid loading configuration early
        @config.load_masterplan masterplan_path unless @config.nil?
      end

      # Process incoming options and take an appropriate action.
      # This is normally called by the mastermind executable.
      #
      # @param cli_args [Array<String>] the arguments to pass into {ArgParse}
      # @return [Void]
      def execute(cli_args=ARGV)
        @arguments = ArgParse.new(cli_args)

        enable_ui if @arguments.display_ui?

        frame('Mastermind') do
          if @arguments.dump_config?
            do_print_configuration
            exit 0
          end

          if @arguments.display_plans?
            do_filtered_plan_display
            exit 0
          end

          process_plan_names

          do_interactive_plan_selection until executable_plan_selected?

          if user_is_sure?
            execute_plan!
          else
            puts 'aborted!'
          end
        end
      end

      # Look up a specific plan by its name
      #
      # Because plans also implement this method in a compatible way, there are
      # three ways this method could be used:
      #
      #  1. List of arguments
      #    * Mastermind['name', 'of', 'plans']
      #
      #  2. Space separated string
      #    * Mastermind['name of plans']
      #
      #  3. Hash-like access
      #    * Mastermind['name']['of']['plans']
      #
      # All will provide the same plan.
      #
      # ---
      #
      # GOTCHA: Be careful if your plan name includes a space!
      #
      # While it's entirely valid to have a plan name that inlcudes a space, you
      # should avoid them if you plan to look up your plan using this method.
      #
      # Plans with spaces in the name can be looked up using only the first form
      # of this method.
      #
      # @param plan_stack [Array<String>] an array of plans to navigate to
      def [](*plan_stack)
        # Allow for a single space-separated string
        if plan_stack.size == 1 and plan_stack.first.is_a?(String)
          plan_stack = plan_stack.first.split(' ')
        end

        plan_stack.compact.reduce(plans) do |plan, plan_name|
          plan[plan_name]
        end
      end

      # Lazy-load the plans to be used by Mastermind
      #
      # @return [ParentPlan] the top-level parent plan which holds all loaded plans
      def plans
        @plans ||= spinner('Loading plans') { Loader.load_all configuration.plan_files }
      end

      private

      # Prints the configuration object built from the loaded masterplan files.
      #
      # @return [Void]
      def do_print_configuration
        frame('Configuration') do
          fade_code = CLI::UI::Color.new(90, '').code
          puts stylize("{{?}} #{fade_code}Values starting with {{*}} #{fade_code}were lazy loaded.#{CLI::UI::Color::RESET.code}")
          print "\n"

          configuration.instance_variables.each do |attribute|
            value = configuration.instance_variable_get(attribute)

            name = attribute.to_s.sub(/^@/, '')

            if value.respond_to? :call
              if @arguments.resolve_callable_attributes?
                value = begin
                          configuration.send(name)
                        rescue => e
                          "UNABLE TO LOAD: #{e.message}"
                        end
              end

              was_callable = true
            else
              was_callable = false
            end

            suffix = was_callable ? '{{*}}' : ' '

            puts stylize("{{yellow:#{name}}}")
            puts stylize("\t #{suffix} {{blue:#{value.inspect}}}")
            print "\n"
          end
        end
      end

      # Filters and displays plans based on the pattern from the passed in arguements
      #
      # @return [Void]
      def do_filtered_plan_display
        filter_plans @arguments.pattern

        unless plans.empty?
          frame('Plans') do
            puts build_display_string
          end
        else
          puts stylize("{{x}} No plans match #{@arguments.pattern.source}")
        end
      end

      # Builds the string that describes a plan.
      #
      # Used for human-readable output of a plan's name, aliases, and description.
      #
      # @param plans [ParentPlan,Hash<name, Plan>] the plans to be displayed
      # @param prefix [String] a prefix to print at the beginning of the output line
      #
      # @return [String] the display string for the given plans
      def build_display_string(plans=self.plans, prefix='')
        fade_code = CLI::UI::Color.new(90, '').code
        reset     = CLI::UI::Color::RESET.code

        display_string = ''

        plans.each do |(name, plan)|
          next unless plan.has_children? or plan.description

          display_string += prefix + '• '
          display_string += stylize("{{yellow:#{titleize(name)} #{fade_code}(#{name})#{reset}\n")

          if plan.aliases.any?
            display_string += prefix + "  - #{fade_code}aliases: #{plan.aliases.to_a.join(', ')}#{reset}\n"
          end

          if plan.description
            display_string += prefix + '  - '
            display_string += stylize("{{blue:#{plan.description}}}\n")
          end

          if plan.has_children?
            display_string += "\n"
            display_string += build_display_string(plan.children, "  " + prefix)
          end

          display_string += "\n"
        end

        # Collapse any run of three or more newlines into just two
        display_string.gsub(/\n{3,}/, "\n\n")
      end

      # Removes plans whose names don't match the given pattern from the tree.
      #
      # Modifies +plans+ in place!
      #
      # @param pattern [Regexp] the pattern to match against
      # @param plans [ParentPlan, Hash<name, Plan>] the plans to filter
      #
      # @return [Void]
      def filter_plans(pattern, plans=self.plans)
        plans.keep_if do |name, plan|
          # Don't display plans without a description or children
          next false unless plan.has_children? or plan.description
          next true if name =~ pattern
          next false unless plan.has_children?

          filter_plans(pattern, plan.children)

          plan.has_children?
        end
      end

      # Processes command line arguements to build the starting plan stack.
      #
      # @see ArgParse
      #
      # @return [Void]
      def process_plan_names
        @arguments.do_command_expansion!(configuration)

        @arguments.insert_base_plan!(@base_plan) unless @base_plan.nil?

        @plan_stack = []

        @selected_plan = plans if @arguments.has_additional_plan_names?

        while @arguments.has_additional_plan_names?
          plan_name = @arguments.get_next_plan_name

          @selected_plan = @selected_plan[plan_name]

          if @selected_plan.nil?
            puts "No plan found at #{(@plan_stack + [titleize(plan_name)]).join('/')}"
            puts @arguments.parser
            exit 1
          end

          @plan_stack << titleize(@selected_plan.name)
        end
      end

      # Asks the user to select a plan from the current list of plans.
      #
      # Repeated invokations of this command allow the user to traverse the plan tree.
      #
      # @return [Void]
      def do_interactive_plan_selection
        options = (@selected_plan || plans).map { |k,v| [titleize(k.to_s), v] }.to_h

        @selected_plan = select("Select a plan under #{@plan_stack.join('/')}", options: options)
        @plan_stack << titleize(@selected_plan.name)
      end

      # @return [Boolean] if the currently selected plan is executable
      def executable_plan_selected?
        not (@selected_plan.nil? or @selected_plan.has_children?)
      end

      # Interaction can be skipped via command line flags (see {ArgParse}) or configuration
      # from a masterplan (see {Configuration})
      #
      # @return [Boolean] if the user is sure they want to execute the given plan
      def user_is_sure?
        !@arguments.ask? or !configuration.ask? or confirm("Execute plan #{@plan_stack.join('/')}?")
      end

      # Executes the selected plan
      #
      # @return [Void]
      def execute_plan!
        @selected_plan.call(@arguments.plan_arguments)
      end
    end
  end
end
