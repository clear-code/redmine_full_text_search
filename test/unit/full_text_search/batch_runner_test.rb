require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class BatchRunnerTest < ActiveSupport::TestCase
    make_my_diffs_pretty!

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def setup
      runner = BatchRunner.new
      runner.synchronize
    end

    def test_synchronize_new
      issue = Issue.generate!
      searcher_record = SearcherRecord.where(original_type: issue.class.name,
                                             original_id: issue.id).first
      searcher_record.destroy!
      runner = BatchRunner.new
      assert_difference("SearcherRecord.count") do
        runner.synchronize
      end
    end

    def test_synchronize_orphan
      issue = Issue.generate!
      searcher_record = SearcherRecord.where(original_type: issue.class.name,
                                             original_id: issue.id).first
      issue.delete
      runner = BatchRunner.new
      assert_difference("SearcherRecord.count", -1) do
        runner.synchronize
      end
    end

    def test_synchronize_outdated
      issue = Issue.generate!
      issue.reload
      searcher_record = SearcherRecord.where(original_type: issue.class.name,
                                             original_id: issue.id).first
      searcher_record.original_updated_on -= 1
      searcher_record.save!
      runner = BatchRunner.new
      n_searcher_records = SearcherRecord.count
      runner.synchronize
      searcher_record.reload
      assert_equal([
                     n_searcher_records,
                     issue.updated_on,
                   ],
                   [
                     SearcherRecord.count,
                     searcher_record.original_updated_on,
                   ])
    end
  end
end
