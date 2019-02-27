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

    def test_save
      filename = "testfile.txt"
      file = uploaded_test_file(filename, "text/plain")
      content = "this is a text file for upload tests\r\nwith multiple lines\r\n"
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

  class AttachmentExtractTest < ActiveSupport::TestCase
    make_my_diffs_pretty!

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def fixture_file_path(name)
      path = Pathname(File.join(__dir__, "..", "..", "files", name)).expand_path
      path.relative_path_from(Pathname(self.class.fixture_path))
    end

    def capture_log
      original_logger = Rails.logger
      begin
        logger = TestLogger.new
        Rails.logger = logger
        yield
        normalize_messages(logger.messages)
      ensure
        Rails.logger = original_logger
      end
    end

    def normalize_messages(messages)
      messages.collect do |level, message|
        [level, message.lines(chomp: true).first]
      end
    end

    def test_encrypted
      filename = "encrypted.zip" # password is "password"
      content_type = "application/zip"
      file = fixture_file_upload(fixture_file_path(filename), content_type)
      attachment = nil
      messages = capture_log do
        attachment = Attachment.generate!(file: file)
      end
      error_messages = messages.find_all do |level, _|
        level == :error
      end
      path = attachment.diskfile
      record = SearcherRecord.where(original_id: attachment.id,
                                    original_type: attachment.class.name).first
      assert_equal([
                     "[full-text-search][text-extract] " +
                     "Failed to extract text: " +
                     "SearcherRecord: #{record.id}: " +
                     "Attachment: #{attachment.id}: " +
                     "path: <#{path}>: " +
                     "content-type: <#{content_type}>: " +
                     "ChupaText::EncryptedError: " +
                     "Encrypted data: <file://#{path}>(#{content_type})",
                   ],
                   error_messages.collect(&:last))
    end

    def test_max_size
      filename = "japanese.txt"
      file = fixture_file_upload(fixture_file_path(filename), "text/plain")
      attachment = nil
      messages = capture_log do
        with_settings(plugin_full_text_search: {
                        "attachment_max_text_size_in_mb" => 7 / 1.megabytes.to_f,
                      }) do
          attachment = Attachment.generate!(file: file)
        end
      end
      info_messages = messages.find_all do |level, message|
        level == :info and message.start_with?("[full-text-search]")
      end
      record = SearcherRecord.where(original_id: attachment.id,
                                    original_type: attachment.class.name).first
      assert_equal([
                     "こん",
                     [
                       "[full-text-search][text-extract] " +
                       "Truncated extracted text: 16 -> 7: " +
                       "SearcherRecord: #{record.id}: " +
                       "Attachment: #{attachment.id}",
                     ]
                   ],
                   [
                     record.content,
                     info_messages.collect(&:last),
                   ])
    end
  end
end
