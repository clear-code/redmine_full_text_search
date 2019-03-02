module FullTextSearch
  class TextExtractor
    def initialize(path, content_type, max_size)
      @path = Pathname(path)
      @content_type = content_type
      @max_size = max_size
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
        break if text.bytesize >= @max_size
      end
      text
    end
  end
end
