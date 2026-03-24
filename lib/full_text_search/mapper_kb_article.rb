module FullTextSearch

  class MapperKbArticle < Mapper
    class << self
      def redmine_mapper_class
        RedmineMapperKbArticle
      end
      def fts_mapper_class
        FtsMapperKbArticle
      end
    end
  end

  class RedmineMapperKbArticle < RedmineMapper
    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.project_id
      fts_target.title = @record.title
      fts_target.content = [@record.summary, @record.content].compact.join("\n")
      fts_target.last_modified_at = @record.updated_at
      fts_target.registered_at = @record.created_at || @record.updated_at
      fts_target.save!
    end
  end

  class FtsMapperKbArticle < FtsMapper
    def title_content
      redmine_record.title
    end
    def description
      redmine_record.content
    end
    def url
      {
        controller: "articles",
        action: "show",
        id: @record.source_id,
        project_id: @record.project_id
      }
    end
    def datetime
      @record.last_modified_at
    end
  end
end
