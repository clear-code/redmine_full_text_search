require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearchControllerTest < Redmine::ControllerTest
    include GroongaCommandExecutable

    make_my_diffs_pretty!

    tests SearchController

    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_fields_trackers
    fixtures :custom_values
    fixtures :enabled_modules
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def setup
      SearcherRecord.sync
      execute_groonga_command("plugin_register functions/vector")
      @request.session[:user_id] = User.admin.first.id
    end

    def format_issue_titles(issues)
      issues.collect do |issue|
        "#{issue.tracker.name} \##{issue.id} (#{issue.status.name}): " +
          "#{issue.subject}"
      end
    end

    class OptionsTest < self
      def test_index
        get :index
        assert_select("#options-content") do
          assert_select(".full-text-search-order")
        end
      end
    end

    class IssueTest < self
      def search(query)
        get :index, params: {"q" => query, "issues" => "1"}
      end

      def test_search
        search("print OR private")
        issues = [
          Issue.find(6),
          Issue.find(1),
        ]
        assert_select("#search-results") do
          assert_equal(format_issue_titles(issues),
                       css_select("dt a").collect(&:text))
        end
      end
    end

    class CustomFieldTest < self
      def search(query, params={})
        get :index, params: {"q" => query, "issues" => "1"}.merge(params)
      end

      def generate_issue!(project, custom_field_values)
        issue = Issue.generate!(project: project)
        issue.custom_field_values = custom_field_values
        issue.save!
        issue
      end

      def test_scoped
        searchable_custom_field = CustomField.where(searchable: true).first
        tracker = searchable_custom_field.trackers.first
        project1, project2, = tracker.projects
        custom_field_values = {
          searchable_custom_field.id => "Searchable",
        }
        issue1 = generate_issue!(project1, custom_field_values)
        issue2 = generate_issue!(project2, custom_field_values)
        search("searchable", id: project1.id)
        assert_select("#search-results") do
          assert_equal(format_issue_titles([issue1]),
                       css_select("dt a").collect(&:text))
        end
      end
    end
  end
end
