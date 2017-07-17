require "groonga/client/response"

module FullTextSearch
  class Searcher
    def initialize
      # TODO: customize instance
    end

    def search(query, limit: 10, offset: 0, all_words: true)
      # pgroonga.command: select v1 or v3 format JSON
      # mroonga.command: select v1 or v3 format JSON
      response = FullTextSearch::SearcherRecord.search(
        query,
        limit: limit,
        offset: offset,
        all_words: all_words
      )
      SearchResult.new(response)
    end
  end

  class SearchResult
    # @param response JSON returned from pgroonga or mroonga
    #
    # auto detect v1 or v3
    def initialize(response)
      command = Groonga::Command.find("select").new("select", {})
      @response = Groonga::Client::Response.parse(command, response)
    end

    # @return Integer the number of records
    def count
      @response.total_count
    end

    def count_by_type
      @response.drilldowns.first.records.map(&:values).to_h
    end

    def records_by_type
      @records_by_type ||= @records.group_by(&:original_type)
    end

    # @return [FullTextSearch::SearcherRecord]
    def records
      @records ||= @response.records.map do |record|
        FullTextSearch::SearcherRecord.from_record(record)
      end
    end

    def raw_records
      @response.records
    end
  end
end
