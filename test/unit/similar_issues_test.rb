require File.expand_path("../../../../../test/test_helper", __FILE__)

class SimilarIssueTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :user_preferences, :members, :member_roles, :roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :versions,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :watchers,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries,
           :repositories,
           :boards, :messages,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  include Redmine::I18n

  def setup
    pend
    set_language_if_valid "en"
  end

  def teardown
    User.current = nil
  end

  def test_similar_issues
    issue = Issue.create!(project_id: 1, tracker_id: 1, author_id: 3,
                          status_id: 1, priority: IssuePriority.all.first,
                          subject: "test",
                          description: "similar issues test")

    Issue.create!(project_id: 1, tracker_id: 1, author_id: 3,
                  status_id: 1, priority: IssuePriority.all.first,
                  subject: "test2",
                  description: "similar issues test")
    assert_nothing_raised do
      similar_issues = issue.similar_issues(user: User.first)
      assert_equal(1, similar_issues.size)
    end
  end
end
