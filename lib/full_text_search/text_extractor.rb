module FullTextSearch
  class TextExtractor
    def initialize(path, content_type)
      @path = Pathname(path)
      @content_type = content_type
    end

    def extract
      data = ChupaText::InputData.new(@path)
      data.mime_type = @content_type
      extractor = ChupaText::Extractor.new
      text = ""
      extractor.extract(data) do |extracted|
        text << extracted.body
      end
      text
    end
  end
end
