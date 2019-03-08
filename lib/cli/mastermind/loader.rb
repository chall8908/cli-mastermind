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

      # Loads a particular plan from the filesystem.
      def load_all(files)
        temp_plan = ParentPlan.new('temporary plan')

        plans = files.map do |file|
          ext = File.extname(file)
          loader = Loader.find_loader(ext)
          temp_plan.add_children loader.load(file)
        end

        temp_plan.children
      end
    end
  end
end

require 'cli/mastermind/loader/planfile_loader'
