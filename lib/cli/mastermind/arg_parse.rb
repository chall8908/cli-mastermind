require 'optparse'

module CLI::Mastermind
  class ArgParse
    # When set, used to display available plans
    attr_reader :pattern

    # Used by mastermind to lookup plans
    # attr_reader :mastermind_arguments

    # Passed as-is into plans
    attr_reader :plan_arguments

    def initialize(arguments=ARGV)
      @initial_arguments = arguments
      @ask = true
      @display_ui = true
      @show_config = false
      @call_blocks = false

      parse_arguments
    end

    def do_command_expansion!(config)
      @alias_arguments = []

      @mastermind_arguments.map! do |argument|
        expand_argument(config, argument)
      end

      @plan_arguments = @alias_arguments + @plan_arguments

      @mastermind_arguments.flatten!
    end

    # Adds the given base plan to the beginning of the arguments array
    def insert_base_plan!(base_plan)
      @mastermind_arguments.unshift base_plan
      nil # prevent @mastermind_arguments from leaking
    end

    def display_plans?
      !@pattern.nil?
    end

    def has_additional_plan_names?
      @mastermind_arguments.any?
    end

    def get_next_plan_name
      @mastermind_arguments.shift
    end

    def display_ui?
      @display_ui
    end

    def ask?
      @ask
    end

    def dump_config?
      @show_config
    end

    def resolve_callable_attributes?
      @call_blocks
    end

    def parser
      @parser ||= OptionParser.new do |opt|
        opt.banner = 'Usage: mastermind [--help, -h] [--plans[ PATTERN], --tasks[ PATTERN], -T [PATTERN], -P [PATTERN] [PLAN[, PLAN[, ...]]] -- [PLAN ARGUMENTS]'

        opt.on('--help', '-h', 'Display this help') do
          puts opt
          exit
        end

        opt.on('-A', '--no-ask', "Don't ask before executing a plan") do
          @ask = false
        end

        opt.on('-U', '--no-fancy-ui', "Don't display the fancy UI") do
          @display_ui = false
        end

        opt.on('--plans [PATTERN]', '--tasks [PATTERN]', '-P', '-T', 'Display plans.  Optional pattern is used to filter the returned plans.') do |pattern|
          @pattern = Regexp.new(pattern || '.')
        end

        opt.on('-C', '--show-configuration', 'Load configuration and print final values.  Give multiple times to resolve lazy attributes as well.') do
          @call_blocks = @show_config
          @show_config = true
        end
      end
    end

    private

    def expand_argument(config, argument)
      dealiased = config.map_alias(argument)

      if dealiased.is_a? Array
        partitioned = dealiased.slice_before('--').to_a

        # Recursively expand plan names
        # NOTE: This does not defend against circular dependencies!
        plan_names = partitioned.shift.map { |arg|  expand_argument(config, arg) }.flatten

        plan_arguments = partitioned.shift

        if plan_arguments
          plan_arguments.shift # removes the --
          @alias_arguments.concat plan_arguments
        end

        dealiased = plan_names
      end

      dealiased
    end

    def parse_arguments
      @mastermind_arguments = @initial_arguments.take_while { |arg| arg != '--' }
      @plan_arguments = @initial_arguments[(@mastermind_arguments.size + 1)..-1] || []

      unless @mastermind_arguments.empty?
        @mastermind_arguments = parser.parse *@mastermind_arguments
      end
    end
  end
end
