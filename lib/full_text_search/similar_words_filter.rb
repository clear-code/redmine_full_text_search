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
      word.
        gsub(@sentence_piece_space, " ").
        unicode_normalize(:nfkc).
        downcase.
        strip
    end

    def ignore_character_only?(word)
      /\A[\p{Number}\p{Punctuation}\p{Symbol}]*\z/.match?(word)
    end

    def multibyte_word?(word)
      not word.ascii_only?
    end

    def sub_word?(word1, word2)
      word1.include?(word2) or word2.include?(word1)
    end

    def target?(source, destination, record)
      return false if source.include?(" ")
      return false if destination.include?(" ")
      return false if source.size == 1
      return false if destination.size == 1
      return false if ignore_character_only?(source)
      return false if ignore_character_only?(destination)
      if multibyte_word?(source) or multibyte_word?(destination)
        return false if sub_word?(source, destination)
      end

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
        destinations = ([source] + destinations).uniq.sort
        next if destinations.size == 1
        destinations.each do |destination|
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
