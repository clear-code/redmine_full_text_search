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
      issue = attachment.container
      targets = Target.where(source_id: attachment.id,
                             source_type_id: Type.attachment.id)
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "source_id" => attachment.id,
                       "source_type_id" => Type.attachment.id,
                       "last_modified_at" => attachment.created_on,
                       "registered_at" => attachment.created_on,
                       "title" => filename,
                       "is_private" => issue.is_private,
                       "content" => [
                         attachment.description,
                         content,
                       ].compact.join("\n"),
                       "container_id" => issue.id,
                       "container_type_id" => Type.issue.id,
                       "custom_field_id" => null_number,
                       "tag_ids" => [
                         Tag.issue_status(issue.status_id).id,
                         Tag.extension("txt").id,
                       ],
                     }
                   ],
                   targets.collect {|target| target.attributes.except("id")})
    end

    def test_destroy
      attachment = Attachment.generate!
      targets = Target.where(source_id: attachment.id,
                             source_type_id: Type.attachment.id)
      assert_equal(1, targets.size)
      attachment.destroy!
      assert_equal([], targets.reload.to_a)
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
      dir = File.dirname(__FILE__)
      path = Pathname(File.join(dir, "..", "..", "files", name)).expand_path
      fixture_path = if self.class.respond_to?(:fixture_paths=)
                       Pathname(self.class.fixture_paths.first)
                     else
                       Pathname(self.class.fixture_path)
                     end
      fixture_path += "files" if Rails::VERSION::MAJOR >= 6
      path.relative_path_from(fixture_path)
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
      fts_target_id = context[:fts_target].id
      formatted_message = "[full-text-search][text-extract] "
      formatted_message << "#{message}: "
      formatted_message << "FullTextSearch::Target: <#{fts_target_id}>: "
      formatted_message << "Attachment: <#{context[:attachment].id}>: "
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
      path = attachment.filename
      context = {
        attachment: attachment,
        fts_target: attachment.to_fts_target,
        path: path,
        content_type: content_type,
      }
      error_message = "ChupaText::EncryptedError: " +
                      "Encrypted data: <#{attachment.diskfile}>(#{content_type})"
      assert_equal([
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
      target = attachment.to_fts_target
      context = {
        attachment: attachment,
        fts_target: target,
        path: attachment.filename,
        content_type: "text/plain",
      }
      assert_equal([
                     "こん",
                     [
                       [
                         :info,
                         format_log_message("Extracted",
                                            context),
                       ],
                     ],
                   ],
                   [
                     target.content,
                     messages,
                   ])
    end

    def test_have_null
      filename = "have-null.txt"
      file = fixture_file_upload(fixture_file_path(filename), "text/plain")
      attachment = nil
      messages = capture_log do
        attachment = Attachment.generate!(file: file)
      end
      target = attachment.to_fts_target
      context = {
        attachment: attachment,
        fts_target: target,
        path: attachment.filename,
        content_type: "text/plain",
      }
      assert_equal([
                     "AB\n",
                     [
                       [
                         :info,
                         format_log_message("Extracted",
                                            context),
                       ],
                     ],
                   ],
                   [
                     target.content,
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
        target = attachment.to_fts_target
        assert_equal("one page", target.content)
      end
    end
  end
end
