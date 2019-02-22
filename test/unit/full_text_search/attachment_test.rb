require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class AttachmentTest < ActiveSupport::TestCase
    make_my_diffs_pretty!

    include NullValues

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def test_save_issue
      filename = "testfile.txt"
      file = uploaded_test_file(filename, "text/plain")
      content = "this is a text file for upload tests with multiple lines"
      attachment = Attachment.generate!(file: file)
      attachment.reload
      records = SearcherRecord.where(original_id: attachment.id,
                                     original_type: attachment.class.name)
      assert_equal([
                     {
                       "project_id" => attachment.container.project_id,
                       "project_name" => attachment.container.project.name,
                       "original_id" => attachment.id,
                       "original_type" => attachment.class.name,
                       "original_created_on" => attachment.created_on,
                       "original_updated_on" => null_datetime,
                       "name" => null_string,
                       "description" => attachment.description || null_string,
                       "identifier" => null_string,
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => null_number,
                       "is_private" => attachment.container.is_private,
                       "status_id" => attachment.container.status_id,
                       "issue_id" => attachment.container.id,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "content" => content,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
                       "text" => null_string,
                       "value" => null_string,
                       "custom_field_id" => null_number,
                       "container_id" => attachment.container.id,
                       "container_type" => attachment.container_type,
                       "filename" => filename,
                     }
                   ],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_destroy
      attachment = Attachment.generate!
      records = SearcherRecord.where(original_id: attachment.id,
                                     original_type: attachment.class.name)
      assert_equal(1, records.size)
      attachment.destroy!
      assert_equal([], records.reload.to_a)
    end
  end
end
