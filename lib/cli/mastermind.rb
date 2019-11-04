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
  module Mastermind
    extend UserInterface

    class << self
      # Expose the configuration loaded during +execute+.
      def configuration
        @config ||= spinner('Loading configuration') { Configuration.new @base_path }
      end

      # Allows utilities wrapping Mastermind to specify that only plans under a
      # particular path should be loaded.
      def base_path=(base_path)
        @base_path = base_path
      end

      # Allows utilities wrapping Mastermind to specify a top level plan without
      # having to monkey with the incomming arguments.
      def base_plan=(base_plan)
        @base_plan = base_plan
      end

      # Allows utilities wrapping Mastermind to specify planfiles that should be
      # automatically loaded.  Plans loaded this way are loaded _after_ all other
      # planfiles and so should only be used to set default values.
      def autoload_masterplan(plan_file_path)
        path = Pathname.new plan_file_path
        raise Error, "`#{plan_file_path}` is not an absolute path" unless path.absolute?
        raise Error, "`#{plan_file_path}` does not exist or is not a file" unless path.file?
        @autoloads ||= []
        @autoloads << plan_file_path
      end

      # Process incoming options and take an appropriate action.
      # This is normally called by the mastermind executable.
      def execute(cli_args=ARGV)
        @arguments = ArgParse.new(cli_args)

        enable_ui if @arguments.display_ui?

        frame('Mastermind') do
          if @autoloads && @autoloads.any?
            @autoloads.each { |masterplan| configuration.load_masterplan masterplan }
          end

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
      def [](*plan_stack)
        # Allow for a single space-separated string
        if plan_stack.size == 1 and plan_stack.first.is_a?(String)
          plan_stack = plan_stack.first.split(' ')
        end

        plan_stack.compact.reduce(plans) do |plan, plan_name|
          plan[plan_name]
        end
      end

      private

      def plans
        @plans ||= spinner('Loading plans') { Loader.load_all configuration.plan_files }
      end

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

      def process_plan_names
        @arguments.do_command_expansion!(configuration)

        @arguments.insert_base_plan!(@base_plan) unless @base_plan.nil?

        @plan_stack = []

        @selected_plan = plans if @arguments.has_additional_plan_names?

        while @arguments.has_additional_plan_names?
          plan_name = @arguments.get_next_plan_name

          @selected_plan = @selected_plan[plan_name]
          @plan_stack << titleize(plan_name)

          if @selected_plan.nil?
            puts "No plan found at #{@plan_stack.join('/')}"
            puts @arguments.parser
            exit 1
          end
        end
      end

      def do_interactive_plan_selection
        options = (@selected_plan&.children || plans).map { |k,v| [titleize(k.to_s), v] }.to_h

        @selected_plan = select("Select a plan under #{@plan_stack.join('/')}", options: options)
        @plan_stack << titleize(@selected_plan.name)
      end

      def executable_plan_selected?
        not (@selected_plan.nil? or @selected_plan.has_children?)
      end

      def user_is_sure?
        !@arguments.ask? or !configuration.ask? or confirm("Execute plan #{@plan_stack.join('/')}?")
      end

      def execute_plan!
        @selected_plan.call(@arguments.plan_arguments)
      end
    end
  end
end
