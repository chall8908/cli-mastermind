require 'set'

module CLI
  module Mastermind
    ##
    # Main configuration object.  Walks up the file tree looking for masterplan
    # files and loading them to build a the configuration used by the CLI.
    #
    # These masterplan files are loaded starting from the current working directory
    # and traversing up until a masterplan with a `at_project_root` directive or
    # or the directory specified by a `project_root` directive is reached.
    #
    # Configuration options set with `configure` are latched once set to something
    # non-nil.  This, along with the aforementioned load order of masterplan files,
    # means that masterplan files closest to the source of your invokation will
    # "beat" other masterplan files.
    #
    # A global masterplan located at $HOME/.masterplan (or equivalent) is loaded
    # _last_.  You can use this to specify plans you want accessible everywhere
    # or global configuration that should apply everywhere (unless overridden by
    # more proximal masterplans).
    #
    # Additionally, there is a directive (`see_other`) that allows for masterplan
    # files outside of the lookup tree to be loaded.
    #
    # See {DSL} for a full list of the commands provided by Mastermind and a sample
    # masterplan file.
    class Configuration
      # Filename of masterplan files
      PLANFILE = '.masterplan'

      # Path to the top-level masterplan
      MASTER_PLAN = File.join(Dir.home, PLANFILE)

      # The set of planfiles to load
      attr_reader :plan_files

      # Adds an arbitrary attribute given by +attribute+ to the configuration class
      #
      # @param attribute [String,Symbol] the attribute to define
      #
      # @!macro [attach] add_attribute
      #   @!attribute [rw] $1
      def self.add_attribute(attribute)
        return if self.method_defined? attribute

        define_method "#{attribute}=" do |new_value=nil, &block|
          self.instance_variable_set("@#{attribute}", new_value.nil? ? block : new_value) if self.instance_variable_get("@#{attribute}").nil?
        end

        define_method attribute do
          value = self.instance_variable_get("@#{attribute}")
          return value unless value.respond_to?(:call)

          # Cache the value returned by the block so we're not doing potentially
          # expensive operations mutliple times.
          self.instance_variable_set("@#{attribute}", self.instance_eval(&value))
        end
      end

      # Specifies the directory that is the root of your project.
      # This directory is where Mastermind will stop looking for more
      # masterplans, so it's important that it be set.
      add_attribute :project_root

      # @param base_path [String,nil] plans outside of the base path will be ignored
      def initialize(base_path=nil)
        @base_path = base_path
        @loaded_masterplans = Set.new
        @plan_files = Set.new
        @ask_for_confirmation = true

        # If no alias exists for a particular value, return that value
        @aliases = Hash.new { |_,k| k }

        lookup_and_load_masterplans
        load_masterplan MASTER_PLAN
      end

      # Adds a set of filenames for plans into the set of +@plan_files+.
      #
      # Plans with paths outside the +@base_path+, if set, will be ignored.
      #
      # @param planfiles [Array<String>] new planfiles to add to the set of planfiles
      # @return [Void]
      def add_plans(planfiles)
        allowed_plans = if @base_path.nil?
                          planfiles
                        else
                          planfiles.select { |file| file.start_with? @base_path }
                        end

        @plan_files.merge(allowed_plans)
      end

      # Loads a masterplan using the DSL, if it exists and hasn't been loaded already
      #
      # @param filename [String] the path to the masterplan to load
      # @return [Void]
      def load_masterplan filename
        if File.exists? filename and !@loaded_masterplans.include? filename
          @loaded_masterplans << filename
          DSL.new(self, filename)
        end
      end

      # Defines a user alias
      #
      # @param alias_from [String] the string to be replaced during expansion
      # @param alias_to [String, Array<String>] the expanded argument
      # @return [Void]
      def define_alias(alias_from, alias_to)
        arguments = alias_to.split(' ') if alias_to.is_a? String

        @aliases[alias_from] = arguments unless @aliases.has_key? alias_from
      end

      # Maps an input string to an alias.
      #
      # @param input [String] the value to be replaced
      # @return [String,Array<String>] the replacement alias or the input, if no replacement exists
      def map_alias(input)
        @aliases[input]
      end

      # @return [Boolean] the user's ask_for_confirmation setting
      def ask?
        @ask_for_confirmation
      end

      # Sets +@ask_for_confirmation+ to `false`.
      #
      # @return [false]
      def skip_confirmation!
        @ask_for_confirmation = false
      end

      private

      # Override the default NoMethodError with a more useful MissingConfigurationError.
      #
      # Since the configuration object is used directly by plans for configuration information,
      # accessing non-existant configuration can lead to unhelpful NoMethodErrors.  This replaces
      # those errors with more helpful errors.
      def method_missing(symbol, *args)
        super
      rescue NoMethodError
        raise MissingConfigurationError, symbol
      end

      # Walks up the file tree looking for masterplans.
      #
      # @return [Void]
      def lookup_and_load_masterplans
        load_masterplan File.join(Dir.pwd, PLANFILE)

        # Walk up the tree until we reach the project root, the home directory, or
        # the root directory
        unless [project_root, Dir.home, '/'].include? Dir.pwd
          Dir.chdir('..') { lookup_and_load_masterplans }
        end
      end

      # Describes the DSL used in masterplan files.
      #
      # See the .masterplan file in the root of this repo for a full example of
      # the available options.
      class DSL
        # @param config [Configuration] the configuration object used by the DSL
        # @param filename [String] the path to the masterplan to be loaded
        def initialize(config, filename)
          @config = config
          @filename = filename
          instance_eval(File.read(filename), filename, 0) if File.exists? filename
        end

        # Specifies that another masterplan should also be loaded when loading
        # this masterplan.  NOTE: This _immediately_ loads the other masterplan.
        #
        # @param filename [String] the path to the masterplan to be loaded
        def see_also(filename)
          @config.load_masterplan(File.expand_path(filename))
        end

        # Specifies the root of the project.
        # +root+ must be a directory.
        #
        # @param root [String] the root directory of the project
        # @raise [InvalidDirectoryError] if +root+ is not a directory
        def project_root(root)
          unless Dir.exist? root
            raise InvalidDirectoryError.new('Invalid project root', root)
          end

          @config.project_root = root
        end

        # Syntactic sugar on top of `project_root` to specify that the current
        # masterplan resides in the root of the project.
        #
        # @see project_root
        def at_project_root
          project_root File.dirname(@filename)
        end

        # Specify that plans exist in the given +directory+.
        # Must be a valid directory.
        #
        # @param directory [String] path to a directory containing planfiles
        # @raise [InvalidDirectoryError] if +directory+ is not a directory
        def plan_files(directory)
          unless Dir.exist? directory
            raise InvalidDirectoryError.new('Invalid plan file directory', directory)
          end

          planfiles = Dir.glob(File.join(directory, '**', "*{#{supported_extensions}}"))
          planfiles.map! { |file| File.expand_path(file) }

          @config.add_plans(planfiles)
        end

        # Syntactic sugar on top of `plan_files` to specify that plans exist in
        # a +plans/+ directory in the current directory.
        #
        # @see plan_files
        def has_plan_files
          plan_files File.join(File.dirname(@filename), 'plans')
        end

        # Specifies that a specific plan file exists at the given +filename+.
        #
        # @param files [Array<String>] an array of planfile paths
        def plan_file(*files)
          files = files.map { |file| File.expand_path file }

          @config.add_plans(files)
        end

        # Add arbitrary configuration attributes to the configuration object.
        # Use this to add plan specific configuration options.
        #
        # @overload configure(attribute, value=nil, &block)
        #   @example configure(:foo, 'bar')
        #   @example configure(:foo) { 'bar' }
        #   @param attribute [String,Symbol] the attribute to define
        #   @param value [] the value to assign
        #   @param block [#call,nil] a callable that will return the value
        #
        # @overload configure(attribute)
        #   @example configure(foo: 'bar')
        #   @example configure('foo' => -> { 'bar' } # not recommended, but should work
        #   @param attribute [Hash] a single entry hash with the key as the attribute
        #     name and value as the corresponding value
        def configure(attribute, value=nil, &block)
          attribute, value = attribute.first if attribute.is_a? Hash

          Configuration.add_attribute(attribute)
          @config.public_send "#{attribute}=", value, &block
        end
        alias_method :set, :configure

        # Define a user alias.  User aliases are expanded as part of plan selection.
        # @see ArgParse#do_command_expansion!
        #
        # @param name [String] the string to be replaced
        # @param arguments [String,Array<String>] the replacement
        def define_alias(name, arguments)
          @config.define_alias(name, arguments)
        end

        # SKip confirmation before plan execution.
        # Identical to -A.
        def skip_confirmation
          @config.skip_confirmation!
        end

        private

        # Used during planfile loading with a Dir.glob to load only supported planfiles
        #
        # @return [String] a comma separated list of supported file extensions
        def supported_extensions
          Loader.supported_extensions.join(',')
        end
      end
    end
  end
end
