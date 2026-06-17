require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueQueryAnySearchableTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      unless IssueQuery.method_defined?(:sql_for_any_searchable_field)
        skip("Required feature 'sql_for_any_searchable_field' does not exist.")
      end
      unless Redmine::Database.postgresql?
        skip("Required PGroonga now. We will support Mroonga soon.")
      end
      User.current = nil
      Attachment.destroy_all
      Issue.destroy_all
      IssueContent.destroy_all
      Journal.destroy_all
    end

    def test_or_one_word
      subject_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぐるんが")
        end
      description_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(description: "ぐるんが")
        end
      without_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "no-keyword",
                          description: "no-keyword")
        end
      journal_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!.journals.create!(notes: "ぐるんが")
        end
      attachment_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          issue = Issue.generate!
          issue.save_attachments(
            [
              {
                "file" => mock_file_with_options(
                  :original_filename => "groonga.txt"),
                "description" => "ぐるんが"
              }
            ]
          )
          issue.save!
          issue
        end
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
        journal_groonga.issue,
        attachment_groonga
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_two_words
      subject_groonga_description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぐるんが",
                          description: "ぴーじーるんが")
        end
      subject_pgroonga_description_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぴーじーるんが",
                          description: "ぐるんが")
        end
      subject_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(description: "ぐるんが")
        end
      description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(description: "ぴーじーるんが")
        end
      without_keywords =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "no-keyword",
                          description: "no-keyword")
        end
      subject_pgroonga_journal_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぴーじーるんが")
              .journals.create!(notes: "ぐるんが")
        end
      subject_groonga_attachment_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          issue = Issue.generate!(subject: "ぐるんが")
          issue.save_attachments(
            [
              {
                "file" => mock_file_with_options(
                  :original_filename => "pgroonga.txt"),
                "description" => "ぴーじーるんが"
              }
            ]
          )
          issue.save!
          issue
        end
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
        subject_pgroonga_journal_groonga.issue,
        subject_groonga_attachment_pgroonga
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_not_and_two_words
      subject_groonga_description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぐるんが",
                          description: "ぴーじーるんが")
        end
      subject_pgroonga_description_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぴーじーるんが",
                          description: "ぐるんが")
        end
      subject_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(description: "ぐるんが")
        end
      description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(description: "ぴーじーるんが")
        end
      without_keywords =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "no-keyword",
                          description: "no-keyword")
        end
      subject_pgroonga_journal_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぴーじーるんが")
              .journals.create!(notes: "ぐるんが")
        end
      subject_groonga_attachment_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          issue = Issue.generate!(subject: "ぐるんが")
          issue.save_attachments(
            [
              {
                "file" => mock_file_with_options(
                  :original_filename => "pgroonga.txt"),
                "description" => "ぴーじーるんが"
              }
            ]
          )
          issue.save!
          issue
        end
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "!~",
            :values => ["ぐるんが ぴーじーるんが"]
          }
        },
        :sort_criteria => [["id", "asc"]]
      )
      expected_issues = [
        subject_groonga,
        description_pgroonga,
        without_keywords
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_two_words_within_my_projects
      my_user = User.find(1)
      project = Project.generate!
      User.add_to_project(my_user, project)

      # User's project issues.
      subject_groonga_description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project,
                          subject: "ぐるんが",
                          description: "ぴーじーるんが")
        end
      without_keywords =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project,
                          subject: "no-keyword",
                          description: "no-keyword")
        end
      subject_pgroonga_journal_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project, subject: "ぴーじーるんが")
               .journals.create!(notes: "ぐるんが")
        end
      # Another project issue.
      subject_pgroonga_description_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(subject: "ぴーじーるんが",
                          description: "ぐるんが")
        end

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
      bookmark_user = User.find(1)
      bookmarked_project =
        Project.where(id: [bookmark_user.bookmarked_project_ids])
               .first
      no_bookmarked_project = Project.generate!

      # User's bookmarked project issues.
      subject_groonga_description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: bookmarked_project,
                          subject: "ぐるんが",
                          description: "ぴーじーるんが")
        end
      without_keywords =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: bookmarked_project,
                          subject: "no-keyword",
                          description: "no-keyword")
        end
      subject_pgroonga_journal_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: bookmarked_project, subject: "ぴーじーるんが")
              .journals.create!(notes: "ぐるんが")
        end
      # Another project issue.
      subject_pgroonga_description_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: no_bookmarked_project,
                          subject: "ぴーじーるんが",
                          description: "ぐるんが")
        end
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
      my_user = User.find(1)
      project = Project.generate!
      User.add_to_project(my_user, project)

      # User's project issues.
      subject_groonga_description_pgroonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project,
                          subject: "ぐるんが",
                          description: "ぴーじーるんが")
        end
      without_keywords =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project,
                          subject: "no-keyword",
                          description: "no-keyword")
        end
      subject_pgroonga_journal_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project, subject: "ぴーじーるんが")
               .journals.create!(notes: "ぐるんが")
        end
      # Closed issue.
      closed_subject_pgroonga_description_groonga =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: project,
                          subject: "ぴーじーるんが",
                          description: "ぐるんが")
               .close!
        end
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
  end
end
