module FullTextSearch
  class WikiPageMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineWikiPageMapper
      end

      def fts_mapper_class
        FtsWikiPageMapper
      end
    end
  end
  resolver.register(WikiPage, WikiPageMapper)

  class RedmineWikiPageMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class.joins(wiki: :project)
      end
    end

    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.wiki.project_id
      fts_target.title = @record.title
      fts_target.content = @record.text
      fts_target.last_modified_at = @record.updated_on
      fts_target.save!
    end
  end

  class FtsWikiPageMapper < FtsMapper
    def type
      "wiki-page"
    end

    def title_prefix
      "#{l(:label_wiki)}: "
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
