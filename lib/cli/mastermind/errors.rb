module CLI
  module Mastermind
    class Error < StandardError
    end

    class UnsupportedFileTypeError < Error
      def initialize(extension)
        super "Unsupported file type: #{extension}"
      end
    end

    class InvalidPlanError < Error
    end

    class InvalidDirectoryError < Error
      def initialize(message, directory)
        super "#{message}:  #{directory} does not exist or is not a directory"
      end
    end

    class MissingConfigurationError < Error
      def initialize(attribute)
        super "#{attribute} has not been defined.  Call `configure :#{attribute}[, value]` in a `#{Configuration::PLANFILE}` to set it."
      end
    end
  end
end
