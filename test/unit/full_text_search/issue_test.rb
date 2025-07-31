require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_fields_trackers
    fixtures :custom_values
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
                       "registered_at" => issue.created_on,
                       "title" => issue.subject,
                       "content" => issue.description || "",
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

    test "Test that when you update the status of an issue, journal status is also updated" do
      issue = Issue.generate!
      issue.reload
      journal = issue.journals.create!(notes: "comment")
      journal.reload
      issue.status_id = 2
      issue.save!
      issue.reload

      # Redmine 5.0 doesn't have updated_on
      if journal.respond_to?(:updated_on)
        last_modified_at = journal.updated_on
      else
        last_modified_at = journal.created_on
      end
      targets = Target.where(source_id: journal.id,
                             source_type_id: Type.journal.id)
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "source_id" => journal.id,
                       "source_type_id" => Type.journal.id,
                       "last_modified_at" => last_modified_at,
                       "registered_at" => journal.created_on,
                       "title" => null_string,
                       "content" => journal.notes,
                       "tag_ids" => [
                         Tag.user(journal.user_id).id,
                         Tag.tracker(issue.tracker_id).id,
                         Tag.issue_status(issue.status_id).id,
                       ],
                       "is_private" => issue.is_private,
                       "custom_field_id" => null_number,
                       "container_id" => issue.id,
                       "container_type_id" => Type.issue.id,
                     }
                   ],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_destroy
      searchable_custom_field = custom_fields(:custom_fields_002)
      issue = Issue.generate! do |i|
        i.custom_fields = [
          {
            "id" => searchable_custom_field.id.to_s,
            "value" => "Hello",
          },
        ]
      end
      issue_targets = Target.where(source_id: issue.id,
                                   source_type_id: Type.issue.id)
      custom_value_targets = Target.where(container_id: issue.id,
                                          source_type_id: Type.custom_value.id)
      assert_equal([1, 1],
                   [issue_targets.size, custom_value_targets.size])
      issue.destroy!
      assert_equal([[], []],
                   [issue_targets.to_a, custom_value_targets.to_a])
    end
  end
end
