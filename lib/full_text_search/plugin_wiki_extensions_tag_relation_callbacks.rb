module FullTextSearch
  class PluginWikiExtensionsTagRelationCallbacks
    # Wiki Extensions tags
    # https://github.com/haru/redmine_wiki_extensions

    class << self
      def attach
        WikiExtensionsTagRelation.after_create_commit(self)
        WikiExtensionsTagRelation.after_destroy(self)
      end

      def after_commit(record)
        target = Target.find_by(
          source_id: record.wiki_page_id,
          source_type_id: Type.wiki_page.id)
        tag_id = Tag.label(record.tag.name).id
        unless target.tag_ids.include?(tag_id)
          target.tag_ids = target.tag_ids.concat([tag_id])
          target.save!
        end
      end
      alias_method :after_create_commit, :after_commit

      def after_destroy(record)
        target = Target.find_by(
          source_id: record.wiki_page_id,
          source_type_id: Type.wiki_page.id)
        tag_ids = target.tag_ids - [Tag.label(record.tag.name).id]
        target.tag_ids = tag_ids
        target.save!
      end
    end
  end
end

