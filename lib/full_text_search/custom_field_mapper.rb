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
    end

    def destroy_fts_target
      p "destroy_fts_target called"
    end

    def upsert_fts_target(options={})
    end
  end

  class FtsCustomFieldMapper < FtsMapper
    def id
      redmine_record.id
    end
  end
end
