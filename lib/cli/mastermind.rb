require 'cli/ui'
require 'cli/mastermind/arg_parse'
require 'cli/mastermind/configuration'
require 'cli/mastermind/errors'
require 'cli/mastermind/loader'
require 'cli/mastermind/plan'
require 'cli/mastermind/version'


module CLI
  module Mastermind
    class << self
      attr_reader :configuration
      attr_reader :plans

      def execute(cli_args=ARGV)
        CLI::UI::StdoutRouter.enable

        CLI::UI::Frame.open('Mastermind') do
          @config = spinner('Loading configuration') { Configuration.new }
          @plans = spinner('Loading plans') { @config.load_plans }
          @plan_stack = []

          @arguments = ArgParse.new(cli_args)

          @selected_plan = nil

          while @arguments.has_additional_plan_names?
            plan_name = @arguments.get_next_plan_name
            @selected_plan = (@selected_plan || @plans)[plan_name]
            @plan_stack << titlize(plan_name)
            # FIXME: Shitty error message
            raise "Invalid child plan `#{plan_name}`" if @selected_plan.nil?
          end

          # Prevent the prompt from exploading
          if @selected_plan.nil? and @plans.count == 1
            @selected_plan = @plans.values.first
            @plan_stack << titlize(@selected_plan.name)
          end

          while @selected_plan.nil? or @selected_plan.has_children?
            do_interactive_plan_selection
            @plan_stack << titlize(@selected_plan.name)
          end

          if CLI::UI.confirm("Execute plan #{@plan_stack.join('/')}?")
            @selected_plan.call(@arguments.plan_arguments)
          else
            puts 'aborted!'
          end
        end
      end

      private

      def do_interactive_plan_selection
        options = @selected_plan&.children || @plans

        @selected_plan = CLI::UI::Prompt.ask("Select a plan under #{@plan_stack.join('/')}") do |handler|
          options.each do |(name, plan)|
            handler.option(titlize(name)) { plan }
          end
        end
      end

      def titlize(string)
        string.gsub(/[-_-]/, ' ').split(' ').map(&:capitalize).join(' ')
      end

      def spinner(title)
        yield_value = nil

        group = CLI::UI::SpinGroup.new
        group.add(title) do |spinner|
          catch(:success) do
            msg = catch(:fail) do
              yield_value = yield spinner
              throw :success
            end

            puts msg
            CLI::UI::Spinner::TASK_FAILED
          end
        end

        group.wait

        yield_value
      end
    end
  end
end
