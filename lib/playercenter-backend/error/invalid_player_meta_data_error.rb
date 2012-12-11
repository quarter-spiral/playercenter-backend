module Playercenter::Backend::Error
  class InvalidPlayerMetaDataError < BaseError
    def initialize(property_name)
      @property_name = property_name
    end

    def message
      "Invalid player meta data! Only strings, numbers and boolean values are supported. Check the '#{@property_name} property!"
    end
  end
end