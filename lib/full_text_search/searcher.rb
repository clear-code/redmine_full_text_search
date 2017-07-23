require "groonga/client/response"

module FullTextSearch
  class Searcher
    def initialize(query, user, scope, projects, options = {})
      @query = query
      @user = user
      @scope = scope
      @projects = projects
      @options = options
    end

    def search
      project_ids = case
                    when projects.is_a?(Array)
                      projects.map(&:id)
                    when Project
                      [projects.id]
                    else
                      [] # all projects
                    end
      # pgroonga.command: select v1 or v3 format JSON
      # mroonga.command: select v1 or v3 format JSON
      response = FullTextSearch::SearcherRecord.search(
        @query,
        project_ids: project_ids,
        limit: limit,
        offset: offset,
        all_words: all_words,
        order_target: @options[:params][:order_target],
        order_type: @options[:params][:order_type]
      )
      SearchResult.new(response, @options)
    end
  end

  class SearchResult
    # [FullTextSearch::SearcherRecord]
    attr_reader :records

    # @param response JSON returned from pgroonga or mroonga
    #
    # auto detect v1 or v3
    def initialize(response, options = {})
      command = Groonga::Command.find("select").new("select", {})
      @response = Groonga::Client::Response.parse(command, response)
      @options = options
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
