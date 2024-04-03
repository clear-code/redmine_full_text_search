# The MIT License (MIT)
#
# Copyright (c) 2024 Abe Tomoaki <abe@clear-code.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
