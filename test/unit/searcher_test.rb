class SaercherTest < ActiveSupport::TestCase
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
    @admin = User.find(1)
    @user = User.find(2)
  end

  def teardown
    User.current = nil
  end

  def test_admin_search
    Issue.create!(project_id: 1, tracker_id: 1, author_id: 3,
                  status_id: 1, priority: IssuePriority.all.first,
                  subject: "test",
                  description: "admin searcher test")
    searcher = FullTextSearch::Searcher.new(
      "admin searcher test",
      @admin,
      [],
      nil,
      params: { limit: 10, offset: 0, order_target: "score", order_type: "desc" }
    )
    assert_equal(1, searcher.search.count)
  end

  def test_user_search
    Issue.create!(project_id: 1, tracker_id: 1, author_id: 3,
                  status_id: 1, priority: IssuePriority.all.first,
                  subject: "test",
                  description: "user searcher test")
    searcher = FullTextSearch::Searcher.new(
      "user searcher test",
      @admin,
      [],
      nil,
      params: { limit: 10, offset: 0, order_target: "score", order_type: "desc" }
    )
    assert_equal(1, searcher.search.count)
  end
end
