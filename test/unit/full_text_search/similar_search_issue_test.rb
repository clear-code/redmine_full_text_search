require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SimilarSearchIssueTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :roles
    fixtures :trackers
    fixtures :users

    def setup
      IssueContent.destroy_all
      User.current = User.find(1)
      @project = Project.generate!
      User.add_to_project(User.current, @project)
    end

    def test_same_structure_on_issue
      fts_engine_groonga_open_source =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(
            project: @project,
            subject: "ぐるんが",
            description: "高速に検索できます。 オープンソースです。")
        end
      fts_engine_pgroonga_open_source =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(
            project: @project,
            subject: "ぴーじーるんが",
            description: "PostgreSQLに組み込んで高速に検索できます。 オープンソースです。")
        end

      similar_issues =
        fts_engine_groonga_open_source.similar_issues(
          project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga_open_source],
                   similar_issues)

      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_groonga_open_source.update!(description: nil)
      end
      similar_issues =
        fts_engine_groonga_open_source.similar_issues(
          project_ids: [@project.id])
      assert_equal([], similar_issues)
    end

    def test_same_structure_with_journal
      fts_engine_groonga_open_source =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: @project, subject: "ぐるんが")
               .journals.create!(notes: "高速に検索できます。 オープンソースです。")
        end
      fts_engine_pgroonga_open_source =
        perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
          Issue.generate!(project: @project, subject: "ぴーじーるんが")
               .journals.create!(
                 notes: "PostgreSQLに組み込んで高速に検索できます。 オープンソースです。")
        end
      target_issue = fts_engine_groonga_open_source.issue
      similar_issues = target_issue.similar_issues(project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga_open_source.issue],
                   similar_issues)

      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        target_issue.journals.first.destroy
      end
      similar_issues =
        target_issue.reload.similar_issues(project_ids: [@project.id])
      assert_equal([], similar_issues)
    end

    def test_same_structure_with_attachment
      set_tmp_attachments_directory
      fts_engine_groonga =
        Issue.generate!(project: @project, subject: "ぐるんが")
      fts_engine_groonga.save_attachments(
        [
          {
            "file" => mock_file_with_options(
              :original_filename => "groonga-latest.txt"),
            "description" => "高速に検索 オープンソース! 最新情報"
          }
        ]
      )
      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_groonga.save!
      end
      fts_engine_pgroonga =
        Issue.generate!(project: @project, subject: "ぴーじーるんが")
      fts_engine_pgroonga.save_attachments(
        [
          {
            "file" => mock_file_with_options(
              :original_filename => "pgroonga-latest.txt"),
            "description" => "組み込んで高速に検索 オープンソース! 最新情報"
          }
        ]
      )
      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_pgroonga.save!
      end
      similar_issues =
        fts_engine_groonga
          .similar_issues(project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga],
                   similar_issues)

      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_groonga.attachments.first.destroy
      end
      similar_issues =
        fts_engine_groonga
          .reload
          .similar_issues(project_ids: [@project.id])
      assert_equal([], similar_issues)
    end
  end
end
