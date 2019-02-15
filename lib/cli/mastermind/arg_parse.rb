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

      parse_arguments
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
      end
    end

    private

    def parse_arguments
      @mastermind_arguments = @initial_arguments.take_while { |arg| arg != '--' }
      @plan_arguments = @initial_arguments[(@mastermind_arguments.size + 1)..-1]

      unless @mastermind_arguments.empty?
        @mastermind_arguments = parser.parse *@mastermind_arguments
      end
    end
  end
end
