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
      tag_ids = []
      content = @record.content
      if content
        parser = MarkupParser.new(@record.wiki.project)
        content_text, content_tag_ids = parser.parse(content, :text)
        fts_target.content = content_text
        tag_ids.concat(content_tag_ids)
      else
        fts_target.content = nil
      end
      fts_target.tag_ids = tag_ids | plugin_wiki_extensions_tag_ids
      fts_target.last_modified_at = @record.updated_on
      fts_target.registered_at = @record.created_on
      fts_target.save!
    end

    private
    def plugin_wiki_extensions_tag_ids
      return [] unless @record.respond_to?(:wiki_ext_tags)
      @record.wiki_ext_tags.collect do |tag|
        Tag.label(tag.name).id
      end
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
