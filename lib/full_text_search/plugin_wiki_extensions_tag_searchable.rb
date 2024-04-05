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

    def find_fts_target
      Target.find_by(
        source_id: wiki_page_id,
        source_type_id: Type.wiki_page.id)
    end

    def find_fts_tag_label_id
      Tag.label(tag.name).id
    end

    def fts_after_create
      fts_target = find_fts_target
      fts_target.tag_ids |= [find_fts_tag_label_id]
      fts_target.save!
    end

    def fts_after_destroy
      fts_target = find_fts_target
      fts_target.tag_ids -= [find_fts_tag_label_id]
      fts_target.save!
    end
  end
end

