require 'cli/ui'
require 'cli/mastermind/arg_parse'
require 'cli/mastermind/configuration'
require 'cli/mastermind/errors'
require 'cli/mastermind/interface'
require 'cli/mastermind/loader'
require 'cli/mastermind/plan'
require 'cli/mastermind/version'

module CLI
  module Mastermind
    extend Interface

    class << self
      attr_reader :plans

      def configuration
        @config
      end

      def execute(cli_args=ARGV)
        @arguments = ArgParse.new(cli_args)

        enable_ui if @arguments.display_ui?

        frame('Mastermind') do
          @config = spinner('Loading configuration') { Configuration.new }
          @plans = spinner('Loading plans') { @config.load_plans }
          @plan_stack = []

          @selected_plan = nil

          while @arguments.has_additional_plan_names?
            plan_name = @arguments.get_next_plan_name
            @selected_plan = (@selected_plan || @plans)[plan_name]
            @plan_stack << titleize(plan_name)
            raise NoPlanFoundError.new(plan_stack) if @selected_plan.nil?
          end

          # Prevent the prompt from exploading
          if @selected_plan.nil? and @plans.count == 1
            @selected_plan = @plans.values.first
            @plan_stack << titleize(@selected_plan.name)
          end

          while @selected_plan.nil? or @selected_plan.has_children?
            do_interactive_plan_selection
            @plan_stack << titleize(@selected_plan.name)
          end

          if !@arguments.ask? or confirm("Execute plan #{@plan_stack.join('/')}?")
            @selected_plan.call(@arguments.plan_arguments)
          else
            puts 'aborted!'
          end
        end
      end

      private

      def do_interactive_plan_selection
        options = @selected_plan&.children || @plans

        @selected_plan = select("Select a plan under #{@plan_stack.join('/')}", options: options)
      end

    end
  end
end
