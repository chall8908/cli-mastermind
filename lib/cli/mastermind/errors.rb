module CLI
  module Mastermind
    class Error < StandardError
    end

    class UnsupportedFileTypeError < Error
      def initialize(extension)
        super "Unsupported file type: #{extension}"
      end
    end
  end
end
