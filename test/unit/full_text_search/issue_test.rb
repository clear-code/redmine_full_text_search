require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def test_save
      issue = Issue.generate!
      issue.reload
      targets = Target.where(source_id: issue.id,
                             source_type_id: Type.issue.id)
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "source_id" => issue.id,
                       "source_type_id" => Type.issue.id,
                       "last_modified_at" => issue.updated_on,
                       "title" => issue.subject,
                       "content" => issue.description || null_string,
                       "tag_ids" => [
                         Tag.tracker(issue.tracker_id).id,
                         Tag.user(issue.author_id).id,
                         Tag.issue_status(issue.status_id).id,
                       ],
                       "is_private" => issue.is_private,
                       "custom_field_id" => null_number,
                       "container_id" => null_number,
                       "container_type_id" => null_number,
                     }
                   ],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_destroy
      issue = Issue.generate!
      targets = Target.where(source_id: issue.id,
                             source_type_id: Type.issue.id)
      assert_equal(1, targets.size)
      issue.destroy!
      assert_equal([], targets.reload.to_a)
    end
  end
end
