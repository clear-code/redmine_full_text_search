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
        deserialize_string(value)
      end
    end

    def serialize(value)
      return nil if value.nil?
      serialize_value(value)
    end

    if Target.mroonga_vector_load_is_supported?
      def deserialize_string(string)
        if string.start_with?("[") and string.end_with?("]")
          JSON.parse(string)
        else
          string.unpack("l*")
        end
      end

      def serialize_value(value)
        value.to_json
      end
    else
      def deserialize_string(string)
        string.unpack("l*")
      end

      def serialize_value(value)
        ""
      end
    end
  end
end
