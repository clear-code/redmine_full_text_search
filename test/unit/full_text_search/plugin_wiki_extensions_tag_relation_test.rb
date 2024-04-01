require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class PluginWikiExtensionsTagRelationTest < ActiveSupport::TestCase
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
      wiki_ext_tags = WikiExtensionsTag.
        where(name: ['tag-0', 'tag-2']).
        collect{ |tag| [tag.id, tag.name] }.
        to_h
      @page.set_tags(wiki_ext_tags)
      @page.reload
    end

    def test_save
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

    def test_save_add_wiki_et_tag
      wiki_ext_tags = WikiExtensionsTag.
        all.
        collect{ |tag| [tag.id, tag.name] }.
        to_h
      @page.set_tags(wiki_ext_tags)

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

    def test_destroy
      wiki_ext_tags = WikiExtensionsTag.
        where(name: ['tag-2']).
        collect{ |tag| [tag.id, tag.name] }.
        to_h
      @page.set_tags(wiki_ext_tags)

      target = Target.find_by(source_id: @page.id,
                              source_type_id: Type.wiki_page.id)
      assert_equal(
        [Tag.label('tag-2').id],
        target.tag_ids
      )
    end
  end
end
