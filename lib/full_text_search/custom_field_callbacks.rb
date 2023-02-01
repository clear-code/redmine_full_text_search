module FullTextSearch
  # We need this because CustomField uses `has_many :custom_values,
  # :dependent => :delete_all` relation. We need `after_destroy`
  # callback to synchronize `CustomFieldValue` and
  # `FullTextSearch::Target(source_type_id: Type.custom_value.id)` but
  # `after_destory` callback doesn't exist with `:dependent =>
  # :delete_all`.
  class CustomFieldCallbacks
    class << self
      def attach
        CustomField.after_destroy(self)
      end

      def after_destroy(record)
        Target
          .where(source_type_id: Type.custom_value.id,
                 custom_field_id: record.id)
          .destroy_all
      end
    end
  end
end
