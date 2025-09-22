begin
  require File.expand_path("../../../application_system_test_case", __FILE__)
rescue => error
  if error.class.name == "Webdrivers::VersionError"
    puts("Webdrivers < 5.3.0 doesn't work. " +
         "See also: https://github.com/titusfortner/webdrivers/pull/251")
    puts("#{error.class}: #{error}")
    return
  else
    raise
  end
end

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
    fixtures :member_roles
    fixtures :messages
    fixtures :news
    fixtures :projects
    fixtures :projects_trackers
    fixtures :repositories
    fixtures :roles
    fixtures :trackers
    fixtures :users
    fixtures :wiki_contents
    fixtures :wiki_pages
    fixtures :wikis

    setup do
      if Object.const_defined?(:Webdrivers)
        if Gem::Version.new(Webdrivers::VERSION) < Gem::Version.new("5.3.0")
          skip("Webdrivers < 5.3.0 doesn't work. " +
               "See also: https://github.com/titusfortner/webdrivers/pull/251")
        end
      end

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
      within("#search-result") do
        within("#search-result-content") do
          within("#search-source-types") do
            find_link("search-target-wiki-pages",
                      class: "selected")
          end
        end
      end
    end

    def test_no_pagination
      subproject1 = Project.find("subproject1")
      visit(url_for(controller: "search",
                    action: "index",
                    id: subproject1.identifier))
      click_on("search-target-issues")
      within("#search-results") do
        assert_equal(2, all("li").size)
      end
      within(".pagination") do
        assert_equal([], all("li").to_a)
      end
    end

    def test_pagination
      visit(search_url)
      click_on("search-target-issues")
      within("#search-results") do
        assert_equal(10, all("li").size)
      end
      within(".pagination") do
        assert_equal("1", find(".current").text)
        find(".next a").click
      end
      within("#search-results") do
        assert_equal(10, all("li").size)
      end
    end
  end
end
