require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class JournalTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def test_save
      journal = Journal.generate!(notes: "Hello!")
      journal.reload
      targets = Target.where(source_id: journal.id,
                             source_type_id: Type.journal.id)
      issue = journal.journalized
      # Redmine 5.0 doesn't have updated_on
      if journal.respond_to?(:updated_on)
        last_modified_at = journal.updated_on
      else
        last_modified_at = journal.created_on
      end
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "source_id" => journal.id,
                       "source_type_id" => Type.journal.id,
                       "last_modified_at" => last_modified_at,
                       "registered_at" => journal.created_on,
                       "title" => null_string,
                       "tag_ids" => [
                         Tag.user(journal.user_id).id,
                         Tag.tracker(issue.tracker_id).id,
                         Tag.issue_status(issue.status_id).id,
                       ],
                       "is_private" => journal.private_notes,
                       "content" => journal.notes,
                       "custom_field_id" => null_number,
                       "container_id" => issue.id,
                       "container_type_id" => Type.issue.id,
                     }
                   ],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_destroy
      journal = Journal.generate!
      targets = Target.where(source_id: journal.id,
                             source_type_id: Type.journal.id)
      assert_equal(1, targets.size)
      journal.destroy!
      assert_equal([], targets.reload.to_a)
    end
  end
end
