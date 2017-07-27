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
      project_ids = case @projects
                    when Array
                      @projects.map(&:id)
                    when Project
                      [@projects.id]
                    else
                      [] # all projects
                    end
      # pgroonga.command: select v1 or v3 format JSON
      # mroonga.command: select v1 or v3 format JSON
      response = FullTextSearch::SearcherRecord.search(
        @query,
        user: @user,
        scope: @scope,
        project_ids: project_ids,
        attachments: @options[:attachments],
        all_words: @options[:all_words],
        titles_only: @options[:titles_only],
        limit: @options[:limit],
        offset: @options[:offset],
        order_target: @options[:params][:order_target],
        order_type: @options[:params][:order_type]
      )
      SearchResult.new(response, query: @query)
    end

    def visible_ids(scope, user, permission)
      if scope.respond_to_(:visible)
        scope.visible(user, permission).pluck(:id)
      else
        Project.allowed_to(user, permission).pluck(:id)
      end
    end
  end

  class SearchResult
    # [FullTextSearch::SearcherRecord]
    attr_reader :records
    attr_reader :tokens

    # @param response JSON returned from pgroonga or mroonga
    #
    # auto detect v1 or v3
    def initialize(response, query:)
      command = Groonga::Command.find("select").new("select", {})
      @response = Groonga::Client::Response.parse(command, response)
      unless @response.success?
        Rails.logger.error(@response.inspect)
      end
      @query = query
      # stolen from Redmine::Search
      # extract tokens from the question
      # eg. hello "bye bye" => ["hello", "bye bye"]
      @tokens = @query.scan(%r{((\s|^)"[^"]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
      # tokens must be at least 2 characters long
      @tokens = @tokens.uniq.select {|w| w.length > 1 }
      # no more than 5 tokens to search for
      @tokens.slice!(5..-1)
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

    def each
      records.each do |record|
        yield record
      end
    end
  end
end
