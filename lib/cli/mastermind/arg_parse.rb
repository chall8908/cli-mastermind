require 'optparse'

module CLI::Mastermind
  # Processes command line arguments and provides a more useful representation of
  # the provided options.
  class ArgParse
    # @return [Regexp] the pattern to use when filtering plans for display
    attr_reader :pattern

    # @return [Array<String>] additional command line arguements passed into the executed plan
    attr_reader :plan_arguments

    # @param arguments [Array<String>] the arguements to parse
    def initialize(arguments=ARGV)
      @initial_arguments = arguments
      @ask = true
      @display_ui = true
      @show_config = false
      @call_blocks = false

      parse_arguments
    end

    # Uses configured user aliases to perform command expansion.
    #
    # For example, an alias defined in a masterplan like so:
    #
    #     define_alias 'foo', 'foobar'
    #
    # when invoked like `mastermind foo` would operate as if the user had actually
    # typed `mastermind foobar`.
    #
    # User aliases (defined in a masterplan) are much more powerful than planfile
    # aliases (defined in a planfile).  Unlike planfile aliases, user aliases
    # can define entire "plan stacks" and are recursively expanded.
    #
    # For example, the following aliases:
    #
    #     define_alias 'foo', 'foobar'
    #     define_alias 'bar', 'foo sub'
    #
    # invoked as `mastermind bar` would operate as if the user had actually typed
    # `mastermind foobar sub`.
    #
    # Plan arguments can also be specified in a user alias.  For example:
    #
    #     define_alias '2-add-2', 'calculator add -- 2 2'
    #
    # would expand as expected with the extra arguements (`'2 2'`) being passed
    # into the executed plan.
    #
    # @param config [Configuration] the configuration object to use when expanding user aliases
    # @return [Void]
    def do_command_expansion!(config)
      @alias_arguments = []

      @mastermind_arguments.map! do |argument|
        expand_argument(config, argument)
      end

      @plan_arguments = @alias_arguments + @plan_arguments

      @mastermind_arguments.flatten!
      nil # prevent @mastermind_arguments from leaking
    end

    # Adds the given base plan to the beginning of the arguments array
    #
    # @param base_plan [String] the base plan to add to the beginning of the arguments
    def insert_base_plan!(base_plan)
      @mastermind_arguments.unshift base_plan
      nil # prevent @mastermind_arguments from leaking
    end

    # @return [Boolean] if the user has requested plan display
    def display_plans?
      !@pattern.nil?
    end

    # @return [Boolean] if additional plan names exist in mastermind's arguments
    def has_additional_plan_names?
      @mastermind_arguments.any?
    end

    # Removes and returns the plan name at the beginning of the argument list.
    #
    # @return [String] the name of the next plan in the list of arguments
    def get_next_plan_name
      @mastermind_arguments.shift
    end

    # @return [Boolean] if the UI is displayed
    def display_ui?
      @display_ui
    end

    # @return [Boolean] if the user should be asked for confirmation prior to plan execution
    def ask?
      @ask
    end

    # @return [Boolean] if the user requested their configuration be displayed
    def dump_config?
      @show_config
    end

    # @return [Boolean] if callable attributes should be resolved prior to being displayed
    def resolve_callable_attributes?
      @call_blocks
    end

    # @return [OptionParser] the parser to process command line arguments with
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

    # Performs alias expansion using the provided configuration object
    #
    # @param config [Configuration] the configuration object used to perform expansion
    # @param argument [String] the argument to be expanded
    #
    # @return [Array<String>, String] the expanded arguments
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

    # Splits the incoming arguments and processes those before the first `--`.
    #
    # Arguments after the first `--` on the command line are passed verbatim into
    # the executed plan.
    def parse_arguments
      @mastermind_arguments = @initial_arguments.take_while { |arg| arg != '--' }
      @plan_arguments = @initial_arguments[(@mastermind_arguments.size + 1)..-1] || []

      unless @mastermind_arguments.empty?
        @mastermind_arguments = parser.parse *@mastermind_arguments
      end
    end
  end
end
