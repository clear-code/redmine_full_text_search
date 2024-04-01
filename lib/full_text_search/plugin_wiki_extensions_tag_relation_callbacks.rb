module FullTextSearch
  class PluginWikiExtensionsTagRelationCallbacks
    # Wiki Extensions tags
    # https://github.com/haru/redmine_wiki_extensions

    class << self
      def attach
        mapper_class = self
        WikiExtensionsTagRelation.class_eval do
          after_commit mapper_class, on: [:create]
          after_destroy mapper_class
        end
      end

      def after_commit(record)
        fts_target = Target.find_by(
          source_id: record.wiki_page_id,
          source_type_id: Type.wiki_page.id)
        tag_id = Tag.label(record.tag.name).id
        unless fts_target.tag_ids.include?(tag_id)
          fts_target.tag_ids = fts_target.tag_ids.concat([tag_id])
          fts_target.save!
        end
      end

      def after_destroy(record)
        fts_target = Target.find_by(
          source_id: record.wiki_page_id,
          source_type_id: Type.wiki_page.id)
        tag_ids = fts_target.tag_ids - [Tag.label(record.tag.name).id]
        fts_target.tag_ids = tag_ids
        fts_target.save!
      end
    end
  end
end

