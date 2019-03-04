module FullTextSearch
  class TextExtractor
    def initialize(path, content_type)
      @path = Pathname(path)
      @content_type = content_type
      settings = Setting.plugin_full_text_search
      ChupaText::ExternalCommand.default_timeout =
        settings.external_command_timeout
      ChupaText::ExternalCommand.default_limit_cpu =
        settings.external_command_timeout
      ChupaText::ExternalCommand.default_limit_as =
        settings.external_command_max_memory
      @max_size = settings.attachment_max_text_size
      @extractor = ChupaText::Extractor.new(max_body_size: @max_size)
      @extractor.apply_configuration(ChupaText::Configuration.default)
    end

    def extract
      data = ChupaText::InputData.new(@path)
      data.mime_type = @content_type
      text = ""
      @extractor.extract(data) do |extracted|
        body = extracted.body
        next if body.empty?
        text << "\n" unless text.empty?
        text << body
        if text.bytesize >= @max_size
          text = text.byteslice(0, @max_size)
          break
        end
      end
      text.scrub!("")
      text
    end
  end
end
