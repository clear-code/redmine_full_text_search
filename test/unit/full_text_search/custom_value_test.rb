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
      records = SearcherRecord.where(original_id: custom_value.id,
                                     original_type: custom_value.class.name)
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "project_name" => issue.project.name,
                       "original_id" => custom_value.id,
                       "original_type" => custom_value.class.name,
                       "original_created_on" => null_datetime,
                       "original_updated_on" => null_datetime,
                       "name" => null_string,
                       "description" => null_string,
                       "identifier" => null_string,
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => null_number,
                       "is_private" => issue.is_private,
                       "status_id" => null_number,
                       "issue_id" => issue.id,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "content" => null_string,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
                       "text" => null_string,
                       "value" => custom_value.value,
                       "custom_field_id" => custom_field.id,
                       "container_id" => null_number,
                       "container_type" => null_string,
                       "filename" => null_string,
                     },
                   ],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_save_project
      project = Project.find(1)
      custom_field = ProjectCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: project)
      custom_value.reload
      records = SearcherRecord.where(original_id: custom_value.id,
                                     original_type: custom_value.class.name)
      assert_equal([
                     {
                       "project_id" => project.id,
                       "project_name" => project.name,
                       "original_id" => custom_value.id,
                       "original_type" => custom_value.class.name,
                       "original_created_on" => null_datetime,
                       "original_updated_on" => null_datetime,
                       "name" => null_string,
                       "description" => null_string,
                       "identifier" => null_string,
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => null_number,
                       "is_private" => null_boolean,
                       "status_id" => null_number,
                       "issue_id" => null_number,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "content" => null_string,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
                       "text" => null_string,
                       "value" => custom_value.value,
                       "custom_field_id" => custom_field.id,
                       "container_id" => null_number,
                       "container_type" => null_string,
                       "filename" => null_string,
                     },
                   ],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_save_user
      user = User.find(2)
      custom_field = UserCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: user)
      custom_value.reload
      records = SearcherRecord.where(original_id: custom_value.id,
                                     original_type: custom_value.class.name)
      assert_equal([],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_save_time_entry_activity
      activity = TimeEntryActivity.first
      custom_field = TimeEntryActivityCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: activity)
      custom_value.reload
      records = SearcherRecord.where(original_id: custom_value.id,
                                     original_type: custom_value.class.name)
      assert_equal([],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_destroy
      issue = Issue.find(1)
      custom_field = IssueCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: issue)
      records = SearcherRecord.where(original_id: custom_value.id,
                                     original_type: custom_value.class.name)
      assert_equal(1, records.size)
      custom_value.destroy!
      assert_equal([], records.reload.to_a)
    end
  end
end
