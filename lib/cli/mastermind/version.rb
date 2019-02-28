module CLI
  module Mastermind

    def self.gem_version
      Gem::Version.new VERSION::STRING
    end

    module VERSION
      RELEASE = 0
      MAJOR = 2
      MINOR = 2
      PATCH = nil

      STRING = [RELEASE, MAJOR, MINOR, PATCH].compact.join('.').freeze
    end
  end
end
