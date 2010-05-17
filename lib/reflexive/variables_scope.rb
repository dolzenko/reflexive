module Reflexive
  class VariablesScope < Hash
    @@guid = 0

    def self.reset_guid
      @@guid = 0
    end

    attr_reader :guid

    def initialize
      super
      @guid = (@@guid += 1)
    end
  end
end