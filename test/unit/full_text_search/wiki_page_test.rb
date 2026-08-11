require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class WikiPageMapperTest < ActiveSupport::TestCase
    fixtures :projects
    fixtures :wikis
    fixtures :users

    def setup
      @wiki = Project.find(1).wiki
      @page = WikiPage.new(wiki: @wiki, title: "WikiPage")
      content = WikiContent.new(page: @page)
      @page.save_with_content(content)
      @attachment = Attachment.generate!(container: @page, author: User.find(2))
    end

    def wiki_page_target
      Target.find_by(source_id: @page.id,
                     source_type_id: Type.wiki_page.id)
    end

    def attachment_target
      Target.find_by(source_id: @attachment.id,
                     source_type_id: Type.attachment.id)
    end

    def test_update_wiki_page
      @page.title = "WikiPageNew"
      @page.save!

      assert_equal("WikiPageNew", wiki_page_target.title)
    end

    def test_move_project_update_attachments
      to_wiki = Project.find(2).wiki
      @page.wiki_id = to_wiki.id
      @page.save!

      assert_equal(2, wiki_page_target.project_id)
      assert_equal(2, attachment_target.project_id)
    end
  end
end
