module FullTextSearch
  class NewsMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineNewsMapper
      end

      def searcher_mapper_class
        SearcherNewsMapper
      end
    end
  end
  resolver.register(News, NewsMapper)

  class RedmineNewsMapper < RedmineMapper
    def upsert_searcher_record(options={})
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.project_id
      searcher_record.project_name = @record.project.name
      searcher_record.title = @record.title
      searcher_record.summary = @record.summary
      searcher_record.description = @record.description
      searcher_record.original_created_on = @record.created_on
      searcher_record.save!
    end
  end

  class SearcherNewsMapper < SearcherMapper
    def url
      {
        controller: "news",
        action: "show",
        id: @record.original_id,
      }
    end
  end
end
