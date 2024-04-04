require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class PluginWikiExtensionsTagSearchableText < ActiveSupport::TestCase
    fixtures :projects
    fixtures :wikis

    def setup
      unless defined?(WikiExtensionsTagRelation)
        skip 'redmine_wiki_extensions is not installed'
      end

      project = Project.find(1)
      3.times do |i|
        WikiExtensionsTag.create(
          name: "tag-#{i}",
          project_id: project.id,
        )
      end

      @page = WikiPage.new(
        wiki: project.wiki,
        title: 'PluginWikiExtensionsTagRelationTest'
      )
      content = WikiContent.new(page: @page)
      @page.save_with_content(content)
    end

    def set_tags(*names)
      wiki_ext_tags = WikiExtensionsTag.
        where(name: names).
        collect{ |tag| [tag.id, tag.name] }.
        to_h
      @page.set_tags(wiki_ext_tags)
      @page.reload
    end

    def test_set_tag
      set_tags('tag-0', 'tag-2')
      target = Target.find_by(source_id: @page.id,
                              source_type_id: Type.wiki_page.id)
      assert_equal(
        [
          Tag.label('tag-0').id,
          Tag.label('tag-2').id
        ].sort,
        target.tag_ids.sort
      )
    end

    def test_add_tag
      # First set tag-0 and tag-2
      set_tags('tag-0', 'tag-2')
      # Add 'tag-1'
      set_tags('tag-0', 'tag-1', 'tag-2')

      target = Target.find_by(source_id: @page.id,
                              source_type_id: Type.wiki_page.id)
      assert_equal(
        [
          Tag.label('tag-0').id,
          Tag.label('tag-1').id,
          Tag.label('tag-2').id
        ].sort,
        target.tag_ids.sort
      )
    end

    def test_remove_tag
      # First set tag-0 and tag-2
      set_tags('tag-0', 'tag-2')
      # Remove 'tag-0'
      set_tags('tag-2')

      target = Target.find_by(source_id: @page.id,
                              source_type_id: Type.wiki_page.id)
      assert_equal(
        [Tag.label('tag-2').id],
        target.tag_ids
      )
    end
  end
end
