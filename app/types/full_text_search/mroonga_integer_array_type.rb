module FullTextSearch
  # TODO: Use ActiveModel::TypeValue when we drop Redmine 3.4 support
  class MroongaIntegerArrayType < ActiveRecord::Type::Value
    def type
      :mroonga_integer_array
    end

    # TODO: Remove this when we drop Redmine 3.4 support
    def type_cast(value)
      deserialize(value)
    end

    def deserialize(value)
      return nil if value.nil?
      return [] if value.empty?
      case value
      when Array
        value
      else
        value.unpack("l*")
      end
    end

    def serialize(value)
      return nil if value.nil?
      ""
    end
  end
end
