require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class CustomValueTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :custom_fields
    fixtures :custom_values
    fixtures :enumerations
    fixtures :issues
    fixtures :projects
    fixtures :users

    def test_save_issue
      issue = Issue.find(1)
      custom_field = IssueCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: issue)
      custom_value.reload
      targets = Target.where(source_id: custom_value.id,
                             source_type_id: Type.custom_value.id)
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "source_id" => custom_value.id,
                       "source_type_id" => Type.custom_value.id,
                       "last_modified_at" => null_datetime,
                       "title" => null_string,
                       "is_private" => issue.is_private,
                       "content" => custom_value.value,
                       "custom_field_id" => custom_field.id,
                       "container_id" => issue.id,
                       "container_type_id" => Type.issue.id,
                       "tag_ids" => null_number_array,
                     },
                   ],
                   targets.all.collect {|target| target.attributes.except("id")})
    end

    def test_save_project
      project = Project.find(1)
      custom_field = ProjectCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: project)
      custom_value.reload
      targets = Target.where(source_id: custom_value.id,
                             source_type_id: Type.custom_value.id)
      assert_equal([
                     {
                       "project_id" => project.id,
                       "source_id" => custom_value.id,
                       "source_type_id" => Type.custom_value.id,
                       "last_modified_at" => null_datetime,
                       "title" => null_string,
                       "is_private" => null_boolean,
                       "content" => custom_value.value,
                       "custom_field_id" => custom_field.id,
                       "container_id" => project.id,
                       "container_type_id" => Type.project.id,
                       "tag_ids" => null_number_array,
                     },
                   ],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_save_user
      user = User.find(2)
      custom_field = UserCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: user)
      custom_value.reload
      targets = Target.where(source_id: custom_value.id,
                             source_type_id: Type.custom_value.id)
      assert_equal([],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_save_time_entry_activity
      activity = TimeEntryActivity.first
      custom_field = TimeEntryActivityCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: activity)
      custom_value.reload
      targets = Target.where(source_id: custom_value.id,
                             source_type_id: Type.custom_value.id)
      assert_equal([],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_destroy
      issue = Issue.find(1)
      custom_field = IssueCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: issue)
      targets = Target.where(source_id: custom_value.id,
                             source_type_id: Type.custom_value.id)
      assert_equal(1, targets.size)
      custom_value.destroy!
      assert_equal([], targets.reload.to_a)
    end
  end
end
