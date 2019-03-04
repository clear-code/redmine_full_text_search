module FullTextSearch
  class WikiContentMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineWikiContentMapper
      end

      def searcher_mapper_class
        SearcherWikiContentMapper
      end
    end
  end
  resolver.register(WikiContent, WikiContentMapper)

  class RedmineWikiContentMapper < RedmineMapper
    def upsert_searcher_record(options={})
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.page_id
      searcher_record.original_type = "WikiPage"
      searcher_record.project_id = @record.page.wiki.project_id
      searcher_record.project_name = @record.page.wiki.project.name
      searcher_record.text = @record.text
      searcher_record.original_updated_on = @record.updated_on
      searcher_record.save!
    end

    private
    def searcher_record_keys
      {
        original_id: @record.page_id,
        original_type: "WikiPage",
      }
    end
  end

  class SearcherWikiContentMapper < SearcherMapper
    def type
      "wiki-page"
    end
  end
end
