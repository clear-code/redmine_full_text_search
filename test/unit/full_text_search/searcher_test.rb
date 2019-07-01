require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearcherTest < ActiveSupport::TestCase
    include PrettyInspectable

    fixtures :attachments
    fixtures :boards
    fixtures :changes
    fixtures :changesets
    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_values
    fixtures :documents
    fixtures :enabled_modules
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :journals
    fixtures :members
    fixtures :messages
    fixtures :news
    fixtures :projects
    fixtures :projects_trackers
    fixtures :repositories
    fixtures :roles
    fixtures :trackers
    fixtures :users
    fixtures :wiki_pages
    fixtures :wikis

    def setup
      runner = BatchRunner.new
      runner.destroy
      runner.synchronize

      @user = User.find(4)
      @project = Project.find(1)
    end

    def search(parameters={})
      request = Request.new(parameters)
      request.user = @user
      request.project = @project
      Searcher.new(request).search
    end

    def test_open_issues
      parameters = {
        issues: "1",
        limit: "-1",
      }
      all_issue_targets = search(parameters).records
      open_issue_targets = search(parameters.merge(open_issues: "1")).records
      diff_targets = all_issue_targets - open_issue_targets
      assert_equal(@project.issues.open(false).order(:id).to_a,
                   diff_targets.collect(&:source_record).sort_by(&:id))
    end
  end
end
