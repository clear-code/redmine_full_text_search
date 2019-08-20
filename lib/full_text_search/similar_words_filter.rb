module FullTextSearch
  class SimilarWordsFilter
    attr_accessor :cosine_threshold
    attr_accessor :engine
    attr_accessor :sentence_piece_space
    def initialize
      @cosine_threshold = 0.99
      @engine = nil
      @sentence_piece_space = "▁"
    end

    def run(records)
      expansions = {}
      records.each do |record|
        source = normalize_word(record["source"])
        destination = normalize_word(record["destination"])
        next unless target?(source, destination, record)
        (expansions[source] ||= []) << destination
        (expansions[destination] ||= []) << source
      end
      generate_records(expansions)
    end

    private
    def normalize_word(word)
      word.gsub(@sentence_piece_space, " ").strip
    end

    def ignore_character_only?(word)
      /\A[\p{Number}\p{Punctuation}\p{Symbol}]*\z/.match?(word)
    end

    def target?(source, destination, record)
      return false if source.include?(" ")
      return false if destination.include?(" ")
      return false if source.size == 1
      return false if destination.size == 1
      return false if ignore_character_only?(source)
      return false if ignore_character_only?(destination)

      cosine = record["cosine"]
      if cosine and cosine < @cosine_threshold
        return false
      end

      if @engine and record["engine"] != @engine
        return false
      end

      true
    end

    def generate_records(expansions)
      records = []
      expansions.keys.sort.each do |source|
        destinations = expansions[source]
        ([source] + destinations).uniq.sort.each do |destination|
          record = {
            "source" => source,
            "destination" => destination,
          }
          records << record
        end
      end
      records
    end
  end
end
