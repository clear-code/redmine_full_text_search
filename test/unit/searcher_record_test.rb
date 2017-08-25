require File.expand_path('../../../../../test/test_helper', __FILE__)

class SearcherRecordTest < ActiveSupport::TestCase
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

  include Redmine::I18n

  def setup
    set_language_if_valid "en"
  end

  def teardown
    User.current = nil
  end

  def test_issue_create
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3,
                      :status_id => 1, :priority => IssuePriority.all.first,
                      :subject => 'test_create',
                      :description => 'SearcherRecordTest#test_create_issue', :estimated_hours => '1:30')
    assert(issue.save)
    issue.reload
    assert_equal(1.5, issue.estimated_hours)

    record = searcher_record("Issue", issue.id)
    project = Project.find(1)
    assert_equal("test_create", record.subject)
    assert_equal(project.name, record.project_name)
  end

  def test_issue_update
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3, :subject => 'test_create')
    assert(issue.save)
    assert_equal("test_create", issue.subject)
    record = searcher_record("Issue", issue.id)
    assert_equal("test_create", record.subject)
    issue.subject = "test_issue_update"
    issue.save!
    record.reload
    assert_equal("test_issue_update", record.subject)
  end

  def test_project_create
    project = Project.create!(:name => "name", identifier: "name")
    record = searcher_record("Project", project.id)
    assert_equal(project.name, record.name)
    assert_equal(project.name, record.project_name)
  end

  def test_project_update
    project = Project.create!(:name => "name", identifier: "name")
    record = searcher_record("Project", project.id)
    assert_equal(project.name, record.name)
    assert_equal(project.name, record.project_name)
    project.update!(:name => "new-name")
    project.reload
    record.reload
    assert_equal(project.name, record.name)
    assert_equal(project.name, record.project_name)
  end

  def test_news_create
    project = Project.find(1)
    news = project.news.create({ :title => 'Test news', :description => 'Lorem ipsum etc', :author => User.first })
    record = searcher_record("News", news.id)
    assert_equal(news.title, record.title)
    assert_equal(news.description, record.description)
    news.update!(:description => "Lorem ipsum etc etc")
    record.reload
    assert_equal(news.description, record.description)
  end

  private

  def searcher_record(original_type, original_id)
    FullTextSearch::SearcherRecord.where(
      original_type: original_type,
      original_id: original_id
    ).first
  end
end
