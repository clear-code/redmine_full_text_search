require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueQueryAnySearchableTest < ActiveSupport::TestCase
    setup do
      unless IssueQuery.method_defined?(:sql_for_any_searchable_field)
        skip("Required feature 'sql_for_any_searchable_field' does not exist.")
      end
      unless Redmine::Database.postgresql?
        skip("Required PGroonga now. We will support Mroonga soon.")
      end
      User.current = nil
    end

    def test_or_one_word
      Issue.destroy_all
      subject_groonga = Issue.generate!(subject: "ぐるんが")
      description_groonga = Issue.generate!(description: "ぐるんが")
      without_groonga = Issue.generate!(subject: "no-keyword",
                                        description: "no-keyword")
      journal_groonga = Issue.generate!.journals.create!(notes: "ぐるんが")
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["ぐるんが"]
          }
        },
        :sort_criteria => [["id", "asc"]]
      )
      expected_issues = [
        subject_groonga,
        description_groonga,
        journal_groonga.issue
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_two_words
      Issue.destroy_all
      subject_groonga_description_pgroonga =
        Issue.generate!(subject: "ぐるんが",
                        description: "ぴーじーるんが")
      subject_pgroonga_description_groonga =
        Issue.generate!(subject: "ぴーじーるんが",
                        description: "ぐるんが")
      subject_groonga = Issue.generate!(description: "ぐるんが")
      description_pgroonga = Issue.generate!(description: "ぴーじーるんが")
      without_keywords = Issue.generate!(subject: "no-keyword",
                                         description: "no-keyword")
      subject_pgroonga_journal_groonga =
        Issue.generate!(subject: "ぴーじーるんが")
             .journals.create!(notes: "ぐるんが")
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["ぐるんが ぴーじーるんが"]
          }
        },
        :sort_criteria => [["id", "asc"]]
      )
      expected_issues = [
        subject_groonga_description_pgroonga,
        subject_pgroonga_description_groonga,
        subject_pgroonga_journal_groonga.issue
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_two_words_within_my_projects
      Issue.destroy_all
      my_user = User.find(1)
      project = Project.generate!
      User.add_to_project(my_user, project)

      # User's project issues.
      subject_groonga_description_pgroonga =
        Issue.generate!(project: project,
                        subject: "ぐるんが",
                        description: "ぴーじーるんが")
      without_keywords = Issue.generate!(project: project,
                                         subject: "no-keyword",
                                         description: "no-keyword")
      subject_pgroonga_journal_groonga =
        Issue.generate!(project: project, subject: "ぴーじーるんが")
             .journals.create!(notes: "ぐるんが")
      # Another project issue.
      subject_pgroonga_description_groonga =
             Issue.generate!(subject: "ぴーじーるんが",
                             description: "ぐるんが")

      User.current = my_user
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["ぐるんが ぴーじーるんが"]
          },
          "project_id" => {
            :operator => "=",
            :values => ["mine"]
          },
        },
        :sort_criteria => [["id", "asc"]]
      )
      expected_issues = [
        subject_groonga_description_pgroonga,
        subject_pgroonga_journal_groonga.issue
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_two_words_within_bookmarks
      Issue.destroy_all
      bookmark_user = User.find(1)
      bookmarked_project =
        Project.where(id: [bookmark_user.bookmarked_project_ids])
               .first
      no_bookmarked_project = Project.generate!

      # User's bookmarked project issues.
      subject_groonga_description_pgroonga =
        Issue.generate!(project: bookmarked_project,
                        subject: "ぐるんが",
                        description: "ぴーじーるんが")
      without_keywords = Issue.generate!(project: bookmarked_project,
                                         subject: "no-keyword",
                                         description: "no-keyword")
      subject_pgroonga_journal_groonga =
        Issue.generate!(project: bookmarked_project, subject: "ぴーじーるんが")
             .journals.create!(notes: "ぐるんが")
      # Another project issue.
      subject_pgroonga_description_groonga =
             Issue.generate!(project: no_bookmarked_project,
                             subject: "ぴーじーるんが",
                             description: "ぐるんが")

      User.current = bookmark_user
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["ぐるんが ぴーじーるんが"]
          },
          "project_id" => {
            :operator => "=",
            :values => ["bookmarks"]
          },
        },
        :sort_criteria => [["id", "asc"]]
      )
      expected_issues = [
        subject_groonga_description_pgroonga,
        subject_pgroonga_journal_groonga.issue
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_two_words_for_open_issues_within_my_projects
      Issue.destroy_all
      my_user = User.find(1)
      project = Project.generate!
      User.add_to_project(my_user, project)

      # User's project issues.
      subject_groonga_description_pgroonga =
        Issue.generate!(project: project,
                        subject: "ぐるんが",
                        description: "ぴーじーるんが")
      without_keywords = Issue.generate!(project: project,
                                         subject: "no-keyword",
                                         description: "no-keyword")
      subject_pgroonga_journal_groonga =
        Issue.generate!(project: project, subject: "ぴーじーるんが")
             .journals.create!(notes: "ぐるんが")
      # Closed issue.
      closed_subject_pgroonga_description_groonga =
        Issue.generate!(project: project,
                        subject: "ぴーじーるんが",
                        description: "ぐるんが")
             .close!

      User.current = my_user
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["ぐるんが ぴーじーるんが"]
          },
          "project_id" => {
            :operator => "=",
            :values => ["mine"]
          },
          'status_id' => {
            :operator => 'o'
          }
        },
        :sort_criteria => [["id", "asc"]]
      )
      expected_issues = [
        subject_groonga_description_pgroonga,
        subject_pgroonga_journal_groonga.issue
      ]
      assert_equal(expected_issues, query.issues)
    end

    # TODO: Add test case to search the attachment's filename and description.
  end
end
