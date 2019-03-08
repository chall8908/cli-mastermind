# coding: utf-8
require 'forwardable'
require 'cli/ui'
require 'cli/mastermind/arg_parse'
require 'cli/mastermind/configuration'
require 'cli/mastermind/errors'
require 'cli/mastermind/user_interface'
require 'cli/mastermind/loader'
require 'cli/mastermind/plan'
require 'cli/mastermind/version'

module CLI
  module Mastermind
    extend UserInterface

    class << self
      # Expose the configuration loaded during +execute+.
      def configuration
        @config
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

      # Process incoming options and take an appropriate action.
      # This is normally called by the mastermind executable.
      def execute(cli_args=ARGV)
        @arguments = ArgParse.new(cli_args)

        enable_ui if @arguments.display_ui?

        frame('Mastermind') do
          @config = spinner('Loading configuration') { Configuration.new @base_path }

          if @arguments.dump_config?
            do_print_configuration
            exit 0
          end

          @plans = spinner('Loading plans') { @config.load_plans }

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

      private

      def do_print_configuration
        frame('Configuration') do
          fade_code = CLI::UI::Color.new(90, '').code
          puts stylize("{{?}} #{fade_code}Values starting with {{*}} #{fade_code}were lazy loaded.#{CLI::UI::Color::RESET.code}")
          print "\n"
          @config.instance_variables.each do |attribute|
            value = @config.instance_variable_get(attribute)

            name = attribute.to_s.sub(/^@/, '')

            if value.respond_to? :call
              if @arguments.resolve_callable_attributes?
                value = begin
                          @config.send(name)
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

        unless @plans.empty?
          frame('Plans') do
            display_plans
          end
        else
          puts stylize("{{x}} No plans match #{@arguments.pattern.source}")
        end
      end

      def display_plans(plans=@plans, prefix='')
        fade_code = CLI::UI::Color.new(90, '').code

        plans.each do |(name, plan)|
          next unless plan.has_children? or plan.description

          print prefix + '• '
          puts stylize("{{yellow:#{titleize(name)} #{fade_code}(#{name})#{CLI::UI::Color::RESET.code}")

          if plan.aliases.any?
            puts prefix + "  - #{fade_code}aliases: #{plan.aliases.to_a.join(', ')}#{CLI::UI::Color::RESET.code}"
          end

          if plan.description
            print prefix + '  - '
            puts stylize("{{blue:#{plan.description}}}")
          end

          display_plans(plan.children, "  " + prefix) if plan.has_children?
          print "\n"
        end
      end

      def filter_plans(pattern, plans=@plans)
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
        @arguments.do_command_expansion!(@config)

        @arguments.insert_base_plan!(@base_plan) unless @base_plan.nil?

        @plan_stack = []

        @selected_plan = @plans if @arguments.has_additional_plan_names?

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
        options = (@selected_plan&.children || @plans).map { |k,v| [titleize(k.to_s), v] }.to_h

        @selected_plan = select("Select a plan under #{@plan_stack.join('/')}", options: options)
        @plan_stack << titleize(@selected_plan.name)
      end

      def executable_plan_selected?
        not (@selected_plan.nil? or @selected_plan.has_children?)
      end

      def user_is_sure?
        !@arguments.ask? or !@config.ask? or confirm("Execute plan #{@plan_stack.join('/')}?")
      end

      def execute_plan!
        @selected_plan.call(@arguments.plan_arguments)
      end
    end
  end
end
