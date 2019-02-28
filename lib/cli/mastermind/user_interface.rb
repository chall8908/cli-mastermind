# Wraps methods from CLI::UI in a slightly nicer DSL
# @see https://github.com/Shopify/cli-ui
module CLI::Mastermind::UserInterface
  # Enables cli-ui's STDOUT Router for fancy UIs
  def enable_ui
    CLI::UI::StdoutRouter.enable
  end

  # :private:
  def ui_enabled?
    CLI::UI::StdoutRouter.enabled?
  end

  # Display a spinner with a +title+ while data is being loaded
  # @returns the value of the given block
  # @see https://github.com/Shopify/cli-ui#spinner-groups
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
  def concurrently
    group = AsyncSpinners.new

    yield group

    group.wait

    group.results
  end

  # Uses +CLI::UI.fmt+ to format a string
  # @see https://github.com/Shopify/cli-ui#symbolglyph-formatting
  def stylize(string)
    CLI::UI.fmt string
  end

  # Opens a CLI::UI frame with the given +title+
  # @see https://github.com/Shopify/cli-ui#nested-framing
  def frame(title)
    return yield unless ui_enabled?
    CLI::UI::Frame.open(title) { yield }
  end

  # Ask the user for some text.
  # @see https://github.com/Shopify/cli-ui#free-form-text-prompts
  def ask(question, default: nil)
    CLI::UI.ask(question, default: default)
  end

  # Ask the user a yes/no +question+
  # @see https://github.com/Shopify/cli-ui#interactive-prompts
  def confirm(question)
    CLI::UI.confirm(question)
  end

  # Display an interactive list of options for the user to select.
  # If less than 2 options would be displayed, the default value is automatically
  # returned.
  #
  # @param +question+ The question to ask the user
  # @param +options:+ Array|Hash the options to display
  # @param +default:+ The default value for this question.  Defaults to the first
  #                   option.  The default option is displayed first.  Assumed to
  #                   exist within the given options.
  #
  # Any other keyword arguments given are passed down into +CLI::UI::Prompt.ask+.
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
  # Replaces any dashes (-) or underscores (_) in the +string+ with spaces and
  # then capitalizes each word.
  #
  # Examples:
  #   titleize('foo') => 'Foo'
  #   titleize('foo bar') => 'Foo Bar'
  #   titleize('foo-bar') => 'Foo Bar'
  #   titleize('foo_bar') => 'Foo Bar'
  def titleize(string)
    string.gsub(/[-_-]/, ' ').split(' ').map(&:capitalize).join(' ')
  end

  class AsyncSpinners < CLI::UI::SpinGroup
    attr_reader :results

    def initialize
      @results = {}
      super
    end

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