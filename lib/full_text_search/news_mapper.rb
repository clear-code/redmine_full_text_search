module FullTextSearch
  class NewsMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineNewsMapper
      end

      def fts_mapper_class
        FtsNewsMapper
      end
    end
  end
  resolver.register(News, NewsMapper)

  class RedmineNewsMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class.joins(:project)
      end
    end

    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.project_id
      fts_target.title = @record.title
      fts_target.content = [
        @record.summary.presence,
        @record.description.presence,
      ].compact.join("\n")
      fts_target.last_modified_at = @record.created_on
      fts_target.registered_at = @record.created_on
      fts_target.save!
    end
  end

  class FtsNewsMapper < FtsMapper
    def url
      {
        controller: "news",
        action: "show",
        id: @record.source_id,
      }
    end
  end
end
