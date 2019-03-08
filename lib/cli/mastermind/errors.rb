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
  end
end
