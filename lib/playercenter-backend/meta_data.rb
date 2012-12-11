module Playercenter::Backend
  class MetaData
    PREFIX = 'playerMeta'

    def self.to_graph(data)
      Hash[data.map do |key, value|
        ensure_value_is_valid!(key, value)

        ["#{PREFIX}#{key}", value]
      end]
    end

    def self.from_graph(data)
      Hash[data.select{|key,value| key.start_with?(PREFIX)}.map do |key, value|
        [key.gsub(/^#{PREFIX}/, ''), value]
      end]
    end

    protected
    def self.ensure_value_is_valid!(property, value)
      raise Error::InvalidPlayerMetaDataError.new(property) unless is_a_supported_data_type?(value)
    end

    def self.is_a_supported_data_type?(value)
      value.kind_of?(String) || value.kind_of?(Numeric) || value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
    end
  end
end