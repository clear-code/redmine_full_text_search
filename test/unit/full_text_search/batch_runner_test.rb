require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class BatchRunnerTest < ActiveSupport::TestCase
    include PrettyInspectable

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
      target = Target.where(source_type_id: Type.issue.id,
                            source_id: issue.id).first
      target.destroy!
      runner = BatchRunner.new
      assert_difference("Target.count") do
        runner.synchronize
      end
    end

    def test_synchronize_orphan
      issue = Issue.generate!
      target = Target.where(source_type_id: Type.issue.id,
                            source_id: issue.id).first
      issue.delete
      runner = BatchRunner.new
      assert_difference("Target.count", -1) do
        runner.synchronize
      end
    end

    def test_synchronize_outdated
      issue = Issue.generate!
      issue.reload
      target = Target.where(source_type_id: Type.issue.id,
                            source_id: issue.id).first
      target.last_modified_at -= 1
      target.save!
      runner = BatchRunner.new
      n_targets = Target.count
      runner.synchronize
      target.reload
      assert_equal([
                     n_targets,
                     issue.updated_on,
                   ],
                   [
                     Target.count,
                     target.last_modified_at,
                   ])
    end
  end
end
