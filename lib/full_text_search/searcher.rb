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
      search_options = {
        user: @user,
        scope: @scope,
        project_ids: project_ids,
        attachments: @options[:attachments],
        all_words: @options[:all_words],
        titles_only: @options[:titles_only],
        open_issues: @options[:open_issues],
        limit: @options[:limit],
        offset: @options[:offset],
        order_target: @options[:params][:order_target],
        order_type: @options[:params][:order_type]
      }
      begin
        # pgroonga_command: select v1 or v3 format JSON
        # mroonga_command: select v1 or v3 format JSON
        response = FullTextSearch::SearcherRecord.search(@query, **search_options)
        SearchResult.new(response, query: @query)
      rescue => ex
        Rails.logger.warn(ex.message)
        # retry with query escape
        search_options[:query_escape] = true
        response = FullTextSearch::SearcherRecord.search(@query, **search_options)
        SearchResult.new(response, query: @query)
      end
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

    # @param response JSON returned from pgroonga or mroonga
    #
    # auto detect v1 or v3
    def initialize(response, query:)
      command = Groonga::Command.find("select").new("select", {})
      @response = Groonga::Client::Response.parse(command, response)
      raise Groonga::Client::Error, @response.message unless @response.success?
      @query = query
    end

    # @return Integer the number of records
    def count
      if @response.success?
        @response.total_count
      else
        0
      end
    end

    def count_by_type
      return {} unless @response.success?
      @response.drilldowns.first.records.inject(Hash.new{|h, k| h[k] = 0 }) do |memo, r|
        key = case r.values[0]
              when "Journal"
                "issues"
              when "WikiContent"
                "wiki_pages"
              else
                r.values[0].tableize
              end
        memo[key] += r.values[1]
        memo
      end
    end

    def records_by_type
      @records_by_type ||= records.group_by(&:original_type)
    end

    # @return [FullTextSearch::SearcherRecord]
    def records
      return [] unless @response.success?
      @records ||= @response.records.map do |record|
        Rails.logger.debug(title: record["title_digest"], description: record["description_digest"])
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
