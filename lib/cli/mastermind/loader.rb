module CLI::Mastermind
  # Loader handles loading planfiles (+not+ masterplans) and is used directly by
  # Mastermind.  Subclasses handle the actual parsing of plans, this class is
  # primarily concerned with finding the correct loader to load a particular
  # file.
  #
  # Loader subclasses are automatically added to the list of loaders.  Thus, adding
  # a new loader is as simple as subclassing and adding the appropriate methods.
  class Loader
    class << self
      attr_reader :loadable_extensions
      @@loaders = []

      # Adds a newly subclasses loader into the set of loaders.
      def inherited(subclass)
        @@loaders << subclass
      end

      # Finds the correct loader for a given extension
      #
      # @param extension [String] the extensions to search with
      # @raise [UnsupportedFileTypeError] if no compatible loader is found
      # @return [Loader] the loader for the given +extension+.
      def find_loader(extension)
        loader = @@loaders.find { |l| l.can_load? extension }

        raise UnsupportedFileTypeError.new(extension) unless loader

        loader
      end

      # @return [Array<String>] all loadable extensions
      def supported_extensions
        @@loaders.flat_map { |l| l.loadable_extensions }
      end

      # @param extension [String] the extension to check
      # @return [Boolean] if the +extension+ is loadable
      def can_load?(extension)
        @loadable_extensions.include? extension
      end

      # @abstract
      # Used to load a given plan.
      #
      # @param filename [String] the path to the planfile to be loaded
      def load(filename)
        raise NotImplementedError
      end

      # Loads plans from the filesystem.
      #
      # The returned ParentPlan is intended for use by Mastermind itself.
      #
      # @param files [Array<String>] the list of planfiles to load
      # @return [ParentPlan] a ParentPlan containing all the loaded plans
      # @private
      def load_all(files)
        temp_plan = ParentPlan.new('INTERNAL PLAN HOLDER')

        plans = files.map do |file|
          ext = File.extname(file)
          loader = Loader.find_loader(ext)
          temp_plan.add_children loader.load(file)
        end

        temp_plan
      end
    end
  end
end

require 'cli/mastermind/loader/planfile_loader'
