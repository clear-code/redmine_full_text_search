require File.expand_path("../../../../../test/test_helper", __FILE__)

class IssueContentTest < ActiveSupport::TestCase
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
           :time_entries

  def test_callback_issue
    issue = Issue.create!(project_id: 1, tracker_id: 1, author_id: 3,
                          status_id: 1, priority: IssuePriority.all.first,
                          subject: "test_callback_issue",
                          description: "IssueContentTest#test_callback_issue", estimated_hours: "1:30")
    record = issue_content(issue.id)
    assert_equal("test_callback_issue\nIssueContentTest#test_callback_issue", record.contents)
    assert_equal(1, record.project_id)
    issue.update!(description: "IssueContentTest#test_callback_issuexxx")
    record.reload
    assert_equal("test_callback_issue\nIssueContentTest#test_callback_issuexxx", record.contents)
  end

  def test_callback_journal
    issue = Issue.create!(project_id: 1, tracker_id: 1, author_id: 3,
                          status_id: 1, priority: IssuePriority.all.first,
                          subject: "test_callback_journal",
                          description: "IssueContentTest#test_callback_journal", estimated_hours: "1:30")
    record = issue_content(issue.id)
    user = User.first
    journal1 = issue.init_journal(user, "Test notes")
    journal1.save!
    record.reload
    assert_equal([issue.subject, issue.description, journal1.notes].join("\n"), record.contents)
    issue.clear_journal
    journal2 = issue.init_journal(user, "Test notes2")
    journal2.save!
    record.reload
    assert_equal([issue.subject, issue.description, journal1.notes, journal2.notes].join("\n"), record.contents)
    journal1.update!(notes: "Test notesxxx")
    record.reload
    assert_equal([issue.subject, issue.description, journal1.notes, journal2.notes].join("\n"), record.contents)
  end

  private

  def issue_content(issue_id)
    FullTextSearch::IssueContent.where(issue_id: issue_id).first
  end
end
