module FullTextSearch
  class SimilarWordsFilter
    def initialize
      @cosign_threshold = 0.95
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

    def target?(source, destination, record)
      return false if source.include?(" ")
      return false if destination.include?(" ")
      return false if source.size == 1
      return false if destination.size == 1
      return false if /\A[\p{Number}\p{Punctuation}]*\z/.match?(source)
      return false if /\A[\p{Number}\p{Punctuation}]*\z/.match?(destination)
      return false if destination.downcase.include?(source.downcase)

      cosine = record["cosine"]
      if cosine and cosine < cosine_threshold
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
