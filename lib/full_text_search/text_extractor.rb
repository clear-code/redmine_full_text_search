module FullTextSearch
  class TextExtractor
    def initialize(path, content_type)
      @path = Pathname(path)
      @content_type = content_type
      @extractor = ChupaText::Extractor.new
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
      end
      text
    end
  end
end
