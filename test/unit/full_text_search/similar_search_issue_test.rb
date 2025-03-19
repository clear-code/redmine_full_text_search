require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SimilarSearchIssueTest < ActiveSupport::TestCase
    def setup
      User.current = User.find(1)
      @project = Project.generate!
      User.add_to_project(User.current, @project)
    end

    def test_same_structure_on_issue
      fts_engine_groonga_open_source =
        Issue.generate!(
          project: @project,
          subject: "ぐるんが",
          description: "高速に検索できます。 オープンソースです。")
      fts_engine_pgroonga_open_source =
        Issue.generate!(
          project: @project,
          subject: "ぴーじーるんが",
          description: "PostgreSQLに組み込んで高速に検索できます。 オープンソースです。")

      similar_issues =
        fts_engine_groonga_open_source.similar_issues(
          project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga_open_source],
                   similar_issues)

      fts_engine_groonga_open_source.update!(description: nil)
      similar_issues =
        fts_engine_groonga_open_source.similar_issues(
          project_ids: [@project.id])
      assert_equal([], similar_issues)
    end

    def test_same_structure_with_journal
      fts_engine_groonga_open_source =
        Issue.generate!(project: @project, subject: "ぐるんが")
             .journals.create!(notes: "高速に検索できます。 オープンソースです。")
      fts_engine_pgroonga_open_source =
        Issue.generate!(project: @project, subject: "ぴーじーるんが")
             .journals.create!(
                notes: "PostgreSQLに組み込んで高速に検索できます。 オープンソースです。")

      target_issue = fts_engine_groonga_open_source.issue
      similar_issues = target_issue.similar_issues(project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga_open_source.issue],
                   similar_issues)

      target_issue.journals.first.destroy
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
      fts_engine_groonga_latest_file.save!
      fts_engine_pgroonga_latest_file =
        Issue.generate!(project: @project, subject: "ぴーじーるんが")
      fts_engine_pgroonga_latest_file.save_attachments(
        {
          '1' => {
            'file' => mock_file_with_options(
              :original_filename => "PGroonga 解説資料 最新版")}
        }
      )
      fts_engine_pgroonga_latest_file.save!

      similar_issues =
        fts_engine_groonga_latest_file
          .similar_issues(project_ids: [@project.id])
      assert_equal([fts_engine_pgroonga_latest_file],
                   similar_issues)

      fts_engine_groonga_latest_file.attachments.first.destroy
      similar_issues =
        fts_engine_groonga_latest_file
          .reload
          .similar_issues(project_ids: [@project.id])
      assert_equal([], similar_issues)
    end
  end
end
