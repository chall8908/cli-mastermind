module CLI
  module Mastermind
    class Error < StandardError
    end

    class NoPlanFoundError < Error
      def initialize(plan_stack)
        super "No plan found at #{plan_stack.join('/')}"
      end
    end

    class UnsupportedFileTypeError < Error
      def initialize(extension)
        super "Unsupported file type: #{extension}"
      end
    end
  end
end
