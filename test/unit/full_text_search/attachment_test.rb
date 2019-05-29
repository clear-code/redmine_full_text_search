require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class AttachmentTest < ActiveSupport::TestCase
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
    include PrettyInspectable

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def setup
      @server = nil
    end

    def setup_server
      port = 40080
      path = "/extraction.json"
      @server_url = "http://127.0.0.1:#{port}#{path}"
      logger = WEBrick::Log.new
      logger.level = logger.class::ERROR
      @server = WEBrick::HTTPServer.new(Port: port,
                                        Logger: logger,
                                        AccessLog: [])
      @server.mount_proc(path) do |request, response|
        response.status = 200
        response.content_type = "application/json"
        response.body = JSON.generate(@server_response)
      end
      @server_thread = Thread.new do
        @server.start
      end
    end

    def teardown
      teardown_server
    end

    def teardown_server
      return if @server.nil?
      @server.shutdown
      @server_thread.join
    end

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
      messages = messages.collect do |level, message|
        [level, message.lines(chomp: true).first]
      end
      messages = messages.find_all do |_level, message|
        message.start_with?("[full-text-search]")
      end
      messages.collect do |level, message|
        [
          level,
          message.gsub(/: (?:elapsed time|memory usage|memory usage diff): <.*?>/,
                       "")
        ]
      end
    end

    def format_log_message(message, context, error_message=nil)
      formatted_message = "[full-text-search][text-extract] "
      formatted_message << "#{message}: "
      formatted_message << "SearcherRecord: #{context[:searcher_record].id}: "
      formatted_message << "Attachment: #{context[:attachment].id}: "
      formatted_message << "path: <#{context[:path]}>: "
      formatted_message << "content-type: <#{context[:content_type]}>"
      formatted_message << ": #{error_message}" if error_message
      formatted_message
    end

    def test_encrypted
      filename = "encrypted.zip" # password is "password"
      content_type = "application/zip"
      file = fixture_file_upload(fixture_file_path(filename), content_type)
      attachment = nil
      messages = capture_log do
        attachment = Attachment.generate!(file: file)
      end
      path = attachment.diskfile
      context = {
        attachment: attachment,
        searcher_record: attachment.to_searcher_record,
        path: path,
        content_type: content_type,
      }
      error_message = "ChupaText::EncryptedError: " +
                      "Encrypted data: <#{path}>(#{content_type})"
      assert_equal([
                     [
                       :info,
                       format_log_message("Extracting...",
                                          context),
                     ],
                     [
                       :error,
                       format_log_message("Failed to extract text",
                                          context,
                                          error_message),
                     ],
                   ],
                   messages)
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
      searcher_record = attachment.to_searcher_record
      context = {
        attachment: attachment,
        searcher_record: searcher_record,
        path: attachment.diskfile,
        content_type: "text/plain",
      }
      assert_equal([
                     "こん",
                     [
                       [
                         :info,
                         format_log_message("Extracting...",
                                            context),
                       ],
                       [
                         :info,
                         format_log_message("Extracted",
                                            context),
                       ],
                     ],
                   ],
                   [
                     searcher_record.content,
                     messages,
                   ])
    end

    def test_server_url
      setup_server
      filename = "one-page.pdf"
      @server_response = {
        "mime-type" => "appliation/pdf",
        "uri" => "file:///tmp/one-page.pdf",
        "path" => "/tmp/one-page.pdf",
        "size" => 100,
        "texts" => [
          {
            "mime-type" => "text/plain",
            "uri" => "file:///tmp/one-page.txt",
            "path" => "/tmp/one-page.txt",
            "size" => 8,
            "source-mime-types" => [
              "application/pdf",
            ],
            "body" => "one page",
          },
        ],
      }
      file = fixture_file_upload(fixture_file_path(filename), "application/pdf")
      with_settings(plugin_full_text_search: {
                      "server_url" => @server_url,
                    }) do
        attachment = Attachment.generate!(file: file)
        searcher_record = attachment.to_searcher_record
        assert_equal("one page", searcher_record.content)
      end
    end
  end
end
