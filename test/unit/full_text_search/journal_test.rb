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
      last_modified_at = journal.updated_on
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
                       "is_private" => issue.is_private,
                       "private_notes" => journal.private_notes,
                       "content" => journal.notes,
                       "custom_field_id" => null_number,
                       "container_id" => issue.id,
                       "container_type_id" => Type.issue.id,
                     }
                   ],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_save_private_issue
      issue = Issue.find(1)
      issue.is_private = true
      issue.save!
      journal = Journal.generate!(notes: "Hello!", journalized: issue)
      targets = Target.where(source_id: journal.id,
                             source_type_id: Type.journal.id)
      assert_equal([[true, false]],
                   targets.collect {|target| [target.is_private, target.private_notes]})
    end

    def test_save_private_notes
      journal = Journal.generate!(notes: "Hello!", private_notes: true)
      targets = Target.where(source_id: journal.id,
                             source_type_id: Type.journal.id)
      assert_equal([[false, true]],
                   targets.collect {|target| [target.is_private, target.private_notes]})
    end

    def test_save_private_issue_and_private_notes
      issue = Issue.find(1)
      issue.is_private = true
      issue.save!
      journal = Journal.generate!(notes: "Hello!",
                                  private_notes: true,
                                  journalized: issue)
      targets = Target.where(source_id: journal.id,
                             source_type_id: Type.journal.id)
      assert_equal([[true, true]],
                   targets.collect {|target| [target.is_private, target.private_notes]})
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
