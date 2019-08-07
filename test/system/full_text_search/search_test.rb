require File.expand_path("../../../application_system_test_case", __FILE__)

module FullTextSearch
  class SearchTest < ApplicationSystemTestCase
    include PrettyInspectable

    fixtures :attachments
    fixtures :boards
    fixtures :changesets
    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_fields_trackers
    fixtures :custom_values
    fixtures :documents
    fixtures :enabled_modules
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :journals
    fixtures :messages
    fixtures :news
    fixtures :projects
    fixtures :projects_trackers
    fixtures :repositories
    fixtures :trackers
    fixtures :users
    fixtures :wiki_contents
    fixtures :wiki_pages
    fixtures :wikis

    setup do
      Target.destroy_all
      batch_runner = BatchRunner.new(show_progress: false)
      batch_runner.synchronize
      log_user("jsmith", "jsmith")
    end

    def test_keep_search_target
      visit(search_url)
      click_on("search-target-wiki-pages")
      fill_in("search-input", with: "cookbook")
      click_on("search-submit")
      assert_equal("selected",
                   find(:link, "search-target-wiki-pages")["class"])
    end
  end
end
