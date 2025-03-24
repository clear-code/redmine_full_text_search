require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SimilarSearchIssueTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    def setup
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
      fts_engine_groonga_latest_file =
        Issue.generate!(project: @project, subject: "ぐるんが")
      fts_engine_groonga_latest_file.save_attachments(
        {
          '1' => {
            'file' => mock_file_with_options(
              :original_filename => "Groonga 解説資料 最新版")}
        }
      )
      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_groonga_latest_file.save!
      end
      fts_engine_pgroonga_latest_file =
        Issue.generate!(project: @project, subject: "ぴーじーるんが")
      fts_engine_pgroonga_latest_file.save_attachments(
        {
          '1' => {
            'file' => mock_file_with_options(
              :original_filename => "PGroonga 解説資料 最新版")}
        }
      )
      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_pgroonga_latest_file.save!
      end
      similar_issues =
        fts_engine_groonga_latest_file
          .similar_issues(project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga_latest_file],
                   similar_issues)

      perform_enqueued_jobs(only: FullTextSearch::UpdateIssueContentJob) do
        fts_engine_groonga_latest_file.attachments.first.destroy
      end
      similar_issues =
        fts_engine_groonga_latest_file
          .reload
          .similar_issues(project_ids: [@project.id])
      assert_equal([], similar_issues)
    end
  end
end
