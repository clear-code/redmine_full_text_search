module FullTextSearch
  class WikiPageMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineWikiPageMapper
      end

      def searcher_mapper_class
        SearcherWikiPageMapper
      end
    end
  end
  resolver.register(WikiPage, WikiPageMapper)

  class RedmineWikiPageMapper < RedmineMapper
    def upsert_searcher_record
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.wiki.project_id
      searcher_record.project_name = @record.wiki.project.name
      searcher_record.title = @record.title
      searcher_record.text = @record.text
      searcher_record.original_created_on = @record.created_on
      searcher_record.original_updated_on = @record.updated_on
      searcher_record.save!
    end
  end

  class SearcherWikiPageMapper < SearcherMapper
    def title_prefix
      "#{l(:label_wiki)}: "
    end

    def description
      @record.text
    end

    def url
      {
        controller: "wiki",
        action: "show",
        project_id: @record.project_id,
        id: @record.title,
      }
    end
  end
end
