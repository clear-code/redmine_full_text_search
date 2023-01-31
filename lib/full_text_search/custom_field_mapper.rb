module FullTextSearch
  class CustomFieldMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineCustomFieldMapper
      end

      def fts_mapper_class
        FtsCustomFieldMapper
      end
    end
  end
  resolver.register(CustomField, CustomFieldMapper)

  class RedmineCustomFieldMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
      end

      def not_mapped(redmine_class, options)
      end

      def have_own_fts_entity?
        false
      end
    end

    def upsert_fts_target(options={})
    end

    def destroy_fts_target
      Target.where(source_type_id: Type.custom_value.id,
                   custom_field_id: @record.id)
            .destroy_all
    end
  end

  class FtsCustomFieldMapper < FtsMapper
  end
end
