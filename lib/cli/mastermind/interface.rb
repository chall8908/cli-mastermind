module CLI::Mastermind::Interface
  def enable_ui
    CLI::UI::StdoutRouter.enable
  end

  def ui_enabled?
    CLI::UI::StdoutRouter.enabled?
  end

  def spinner(title)
    return yield unless ui_enabled?

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

  def frame(title)
    return yield unless ui_enabled?
    CLI::UI::Frame.open(title) { yield }
  end

  def ask(question, default: nil)
    CLI::UI.ask(question, default: default)
  end

  def confirm(question)
    CLI::UI.confirm(question)
  end

  def select(question, options:, default: options.first, **opts)
    default_value = nil
    options = case options
              when Array
                default_value = default

                o = options - [default]
                o.zip(o).to_h
              when Hash
                # Handle the "default" default.  Otherwise, we expect the
                # default to be a key in the options hash
                default = default.first if default.is_a? Array
                default_value = options[default]
                options.dup.tap { |o| o.delete(default) }
              end

    CLI::UI::Prompt.ask(question, **opts) do |handler|
      handler.option(titleize(default.to_s)) { default_value }

      options.each do |(text, value)|
        handler.option(titleize(text.to_s)) { value }
      end
    end
  end

  def titleize(string)
    string.gsub(/[-_-]/, ' ').split(' ').map(&:capitalize).join(' ')
  end
end
