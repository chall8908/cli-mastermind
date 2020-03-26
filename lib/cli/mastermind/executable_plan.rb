module CLI
  module Mastermind
    # Executable Plan implementation.  Used in Planfile Loader to generate executable
    # plans from its DSL.
    class ExecutablePlan
      include Plan

      # Implementation of {Plan#call} which calls the block this plan was created with
      #
      # @param (see Plan#call)
      # @see Plan#call
      def call(options=nil)
        case @block.arity
        when 1, -1 then instance_exec(options, &@block)
        else            instance_exec(&@block)
        end
      end
    end
  end
end
