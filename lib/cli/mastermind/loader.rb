module CLI::Mastermind
  class Loader
    class << self
      attr_reader :loadable_extensions
      @@loaders = []

      def inherited(subclass)
        @@loaders << subclass
      end

      def find_loader(extension)
        loader = @@loaders.find { |l| l.can_load? extension }

        raise UnsupportedFileTypeError.new(extension) unless loader

        loader
      end

      def supported_extensions
        @@loaders.flat_map { |l| l.loadable_extensions }
      end

      def can_load?(extension)
        @loadable_extensions.include? extension
      end

      def load(filename)
        raise NotImplementedError
      end
    end
  end
end

require 'cli/mastermind/loader/planfile_loader'
require 'cli/mastermind/loader/yaml_loader'
