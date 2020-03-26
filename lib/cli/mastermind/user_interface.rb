# Wraps methods from CLI::UI in a slightly nicer DSL
# @see https://github.com/Shopify/cli-ui
module CLI::Mastermind::UserInterface
  # Enables cli-ui's STDOUT Router for fancy UIs
  def enable_ui
    CLI::UI::StdoutRouter.enable
  end

  # @private
  # @return [Boolean] if the StdoutRouter is enabled
  def ui_enabled?
    CLI::UI::StdoutRouter.enabled?
  end

  # Display a spinner with a +title+ while data is being loaded
  #
  # @see https://github.com/Shopify/cli-ui#spinner-groups
  #
  # @param title [String] the title to display
  # @param block [#call] passed to the underlying spinner implementation.
  # @return the result of calling the given +block+
  def spinner(title, &block)
    return yield unless ui_enabled?

    results = concurrently do |actions|
      actions.await(title, &block)
    end

    results[title]
  end
  alias_method :await, :spinner

  # Performs a set of actions concurrently
  # Yields an +AsyncSpinners+ objects which inherits from +CLI::UI::SpinGroup+.
  # The only difference between the two is that +AsyncSpinners+ provides a
  # mechanism for exfiltrating results by using +await+ instead of the usual
  # +add+.
  #
  # @see AsyncSpinners
  #
  # @yieldparam group [AsyncSpinners]
  def concurrently
    group = AsyncSpinners.new

    yield group

    group.wait

    group.results
  end

  # Uses +CLI::UI.fmt+ to format a string
  # @see https://github.com/Shopify/cli-ui#symbolglyph-formatting
  #
  # @param string [String] the string to format
  # @return [String] the formatted string
  def stylize(string)
    CLI::UI.fmt string
  end

  # Opens a CLI::UI frame with the given +args+
  # @see https://github.com/Shopify/cli-ui#nested-framing
  def frame(*args)
    return yield unless ui_enabled?
    CLI::UI::Frame.open(*args) { yield }
  end

  # Ask the user for some text.
  # @see https://github.com/Shopify/cli-ui#free-form-text-prompts
  #
  # @param question [String] the question to ask the user
  # @param default [String] the default answer
  # @return [String] the user's answer
  def ask(question, default: nil)
    CLI::UI.ask(question, default: default)
  end

  # Ask the user a yes/no +question+
  # @see https://github.com/Shopify/cli-ui#interactive-prompts
  #
  # @param question [String] the question to ask the user
  # @return [Boolean] how the user answered
  def confirm(question)
    CLI::UI.confirm(question)
  end

  # Display an interactive list of options for the user to select.
  # If less than 2 options would be displayed, the default value is automatically
  # returned.
  #
  # @param question [String] The question to ask the user
  # @param options [Array<String>,Hash] the options to display
  # @param default [String] The default value for this question.  Assumed to exist
  #   within the given options.
  # @param opts [Hash] additional options passed into +CLI::UI::Prompt.ask+.
  #
  # @see https://github.com/Shopify/cli-ui#interactive-prompts
  def select(question, options:, default: options.first, **opts)
    default_value = nil
    options = case options
              when Array
                default_text = default

                o = options - [default]
                o.zip(o).to_h
              when Hash
                # Handle the "default" default.  Otherwise, we expect the default
                # is the default value
                if default.is_a? Array
                  default_text, default = default
                else
                  default_text = options.invert[default]
                end

                # dup so that we don't change whatever was passed in
                options.dup.tap { |o| o.delete(default_text) }
              end

    return default unless options.count > 0

    CLI::UI::Prompt.ask(question, **opts) do |handler|
      handler.option(default_text.to_s) { default }

      options.each do |(text, value)|
        handler.option(text) { value }
      end
    end
  end

  # Titleize the given +string+.
  #
  # Replaces any dashes (-) or underscores (_) in the +string+ with spaces and
  # then capitalizes each word.
  #
  # @example titleize('foo') => 'Foo'
  # @example titleize('foo bar') => 'Foo Bar'
  # @example titleize('foo-bar') => 'Foo Bar'
  # @example titleize('foo_bar') => 'Foo Bar'
  #
  # @param string [String] the string to titleize.
  def titleize(string)
    string.gsub(/[-_-]/, ' ').split(' ').map(&:capitalize).join(' ')
  end

  # Capture the output of the given command and print them in a cli-ui friendly way.
  # This command is an ease of use wrapper around a common capture construct.
  #
  # The command given can be a single string, an array of strings, or individual
  # arguments.  The command and any kwargs given are passed to IO.popen to capture
  # output.
  #
  # Optionally, a block may be passed to modify the output of the line prior to
  # printing.
  #
  # @param command [Array<String>] the command to execute
  # @param kwargs [Hash] additional arguments to be passed into +IO.popen+
  #
  # @yieldparam line [String] a line of output to be processed
  #
  # @see IO.popen
  # @see Open3.popen
  def capture_command_output(*command, **kwargs, &block)
    # Default block returns what's passed in
    block ||= -> line { line }
    IO.popen(command.flatten, **kwargs) { |io| io.each_line { |line| print block.call(line) } }
  end

  # Implementation of CLI::UI::SpinGroup with that keeps track of the results from
  # individual spinners.
  class AsyncSpinners < CLI::UI::SpinGroup
    attr_reader :results

    def initialize
      @results = {}
      super
    end

    # Waits for a block to execute while displaying a spinner.
    #
    # @param title [String] the title to display
    #
    # @yieldparam spinner [CLI::UI::Spinner]
    def await(title)
      @results[title] = nil

      add(title) do |spinner|
        catch(:success) do
          msg = catch(:fail) do
            @results[title] = yield spinner
            throw :success
          end

          puts msg
          CLI::UI::Spinner::TASK_FAILED
        end
      end
    end
  end
end
