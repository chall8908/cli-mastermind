require 'set'

module CLI
  module Mastermind
    ##
    # Main configuration object.  Walks up the file tree looking for masterplans
    # and loading them into to build a the configuration used by the CLI.
    #
    # Masterplans are loaded such that configuration specified closest to the
    # point of invocation override configuration from farther masterplans.
    # This allows you to add folder specific configuration while still falling
    # back to more and more general configuration options.
    #
    # A global masterplan located at $HOME/.masterplan (or equivalent) is loaded
    # _last_.  You can use this to specify plans you want accessible everywhere
    # or global configuration that should apply everywhere (unless overridden by
    # more specific masterplans).
    class Configuration
      # Filename of masterplan files
      PLANFILE = '.masterplan'

      # Path to the top-level masterplan
      MASTER_PLAN = File.join(Dir.home, PLANFILE)

      attr_reader :plans

      # Adds an arbitrary attribute given by +attribute+ to the configuration class
      def self.add_attribute(attribute)
        return if self.method_defined? attribute

        define_method "#{attribute}=" do |new_value=nil,&block|
          self.instance_variable_set("@#{attribute}", new_value||block)  if self.instance_variable_get("@#{attribute}").nil?
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

      # Adds a set of filenames for plans into the set of +@plan_files+
      def add_plans(planfiles)
        allowed_plans = if @base_path.nil?
                          planfiles
                        else
                          planfiles.select { |file| file.start_with? @base_path }
                        end

        @plan_files.merge(allowed_plans)
      end

      # Loads all plan files added using +add_plans+
      # @see Plan.load
      def load_plans
        @plans = {}

        top_level_plan = Plan.new('temporary_plan')

        @plan_files.each do |file|
          plans = Plan.load file
          top_level_plan.add_children plans
        end

        @plans = top_level_plan.children
      end

      def execute_plan(*plan_stack, arguments: nil)
        if plan_stack.size == 1
          case plan_stack.first
          when Array
            plan_stack = plan_stack.first
          when String
            plan_stack = plan_stack.first.split(' ')
          end
        end

        plan = @plans

        plan_stack.each do |plan_name|
          plan = plan[plan_name]
        end

        plan.call(arguments)
      end

      # Loads a masterplan using the DSL, if it exists and hasn't been loaded already
      def load_masterplan filename
        if File.exists? filename and !@loaded_masterplans.include? filename
          @loaded_masterplans << filename
          DSL.new(self, filename)
        end
      end

      def define_alias(alias_from, alias_to)
        arguments = alias_to.split(' ') if alias_to.is_a? String

        @aliases[alias_from] = arguments unless @aliases.has_key? alias_from
      end

      def map_alias(input)
        @aliases[input]
      end

      def ask?
        @ask_for_confirmation
      end

      def skip_confirmation!
        @ask_for_confirmation = false
      end

      private

      # Walks up the file tree looking for masterplans.
      def lookup_and_load_masterplans
        load_masterplan File.join(Dir.pwd, PLANFILE)

        # Walk up the tree until we reach the project root, the home directory, or
        # the root directory
        unless [project_root, Dir.home, '/'].include? Dir.pwd
          Dir.chdir('..') { lookup_and_load_masterplans }
        end
      end

      class DSL
        def initialize(config, filename)
          @config = config
          @filename = filename
          instance_eval(File.read(filename), filename, 0) if File.exists? filename
        end

        # Specifies that another masterplan should also be loaded when loading
        # this masterplan.  NOTE: This _immediately_ loads the other masterplan.
        def see_also(filename)
          @config.load_masterplan(filename)
        end

        # With no arguments, specifies that the current directory containing this
        # masterplan is at the root of your project.  Otherwise, specifies the root
        # of the project.
        def project_root(root = File.dirname(@filename))
          @config.project_root = root
        end
        alias_method :at_project_root, :project_root

        # With no arguments, specifies that plans exist in a /plans/ directory
        # under the directory the masterplan is in.
        def plan_files(directory = File.join(File.dirname(@filename), 'plans'))
          @config.add_plans(Dir.glob(File.join(directory, '**', "*{#{supported_extensions}}")))
        end
        alias_method :has_plan_files, :plan_files

        # Specifies that a specific plan file exists at the given +filename+.
        def plan_file(*files)
          @config.add_plans(files)
        end

        # Add arbitrary configuration attributes to the configuration object.
        # Use this to add plan specific configuration options.
        def configure(attribute, value=nil, &block)
          attribute, value = attribute.first if attribute.is_a? Hash

          Configuration.add_attribute(attribute)
          @config.public_send "#{attribute}=", value, &block
        end

        # Define a user alias.  User aliases are expanded as part of plan selection.
        # @see ArgParse#do_command_expansion!
        def define_alias(name, arguments)
          @config.define_alias(name, arguments)
        end

        # SKip confirmation before plan execution.
        # Identical to -A.
        def skip_confirmation
          @config.skip_confirmation!
        end

        private

        def supported_extensions
          Loader.supported_extensions.join(',')
        end
      end
    end
  end
end
