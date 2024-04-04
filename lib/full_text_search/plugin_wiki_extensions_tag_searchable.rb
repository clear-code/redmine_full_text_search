module FullTextSearch
  module PluginWikiExtensionsTagSearchable
    # Wiki Extensions tags
    # https://github.com/haru/redmine_wiki_extensions

    extend ActiveSupport::Concern

    included do
      after_create :fts_after_create
      after_destroy :fts_after_destroy
    end

    private

    def fts_after_create
      fts_target = Target.find_by(
        source_id: self.wiki_page_id,
        source_type_id: Type.wiki_page.id)
      tag_id = Tag.label(self.tag.name).id
      fts_target.tag_ids = fts_target.tag_ids.concat([tag_id])
      fts_target.save!
    end

    def fts_after_destroy
      fts_target = Target.find_by(
        source_id: self.wiki_page_id,
        source_type_id: Type.wiki_page.id)
      tag_ids = fts_target.tag_ids - [Tag.label(self.tag.name).id]
      fts_target.tag_ids = tag_ids
      fts_target.save!
    end
  end
end

