module CLI
  module Mastermind
    class ExecutablePlan
      include Plan

      def call(options=nil)
        case @block.arity
        when 1, -1 then instance_exec(options, &@block)
        else            instance_exec(&@block)
        end
      end
    end
  end
end
