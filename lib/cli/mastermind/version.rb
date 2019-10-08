module CLI
  module Mastermind

    def self.gem_version
      Gem::Version.new VERSION::STRING
    end

    module VERSION
      RELEASE = 1
      MAJOR = 0
      MINOR = 0
      PATCH = nil

      STRING = [RELEASE, MAJOR, MINOR, PATCH].compact.join('.').freeze
    end
  end
end
