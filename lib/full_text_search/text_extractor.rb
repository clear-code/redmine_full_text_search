module FullTextSearch
  class TextExtractor
    class << self
      @@extractors = {}
      def extractor
        @@extractors[Thread.current.object_id] ||= build_extractor
      end

      def build_extractor
        extractor = ChupaText::Extractor.new
        extractor.apply_configuration(ChupaText::Configuration.default)
        extractor
      end
    end

    def extract(path, input, content_type)
      apply_settings
      if input
        data = ChupaText::VirtualFileData.new(path, input)
      else
        data = ChupaText::InputData.new(path)
      end
      text = +""
      begin
        data.need_screenshot = false
        data.mime_type = content_type
        data.timeout = @timeout
        data.max_body_size = @max_size
        self.class.extractor.extract(data) do |extracted|
          body = +extracted.body
          extracted.release
          body.scrub!("")
          body.gsub!("\u0000", "")
          next if body.empty?
          text << "\n" unless text.empty?
          text << body
          if text.bytesize >= @max_size
            text = text.byteslice(0, @max_size)
            text.scrub!("")
            break
          end
        end
      ensure
        data.release
      end
      text
    end

    private
    def apply_settings
      settings = Setting.plugin_full_text_search
      @timeout = settings.text_extraction_timeout
      ChupaText::ExternalCommand.default_timeout = @timeout
      ChupaText::ExternalCommand.default_limit_cpu = @timeout
      ChupaText::ExternalCommand.default_limit_as =
        settings.external_command_max_memory
      ChupaText::Decomposers::HTTPServer.default_url =
        settings.server_url
      @max_size = settings.attachment_max_text_size
    end
  end
end
