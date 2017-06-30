module FullTextSearch
  module Search
    # Overwrite full feature of Redmine::Search::Fetcher
    module Fetcher
      def initialize(question, user, scope, projects, options={})
        @user = user
        @question = question.strip
        @scope = scope
        @projects = projects
        @cache = options.delete(:cache)
        @options = options

        # トークンはとりあえずそのまま
        @tokens = @question
      end

      # @return Integer number of all records
      def result_count
        fetch_results.count
      end

      # @return Hash { type: number_of_records, ... }
      def result_count_by_type
        # ドリルダウンしたやつをHashで返すだけ
      end

      # Resultオブジェクトを返してそれが records, count, count_by_type を持つとよさそう
      # view と controller を全部書き直すつもりでやればできそう
      # 元のAPIは↓を期待している
      # @returns Array [Issue, Issue, Project, WikiPage, ...] mixed models array
      def results(offset, limit)
        results = fetch_retults
        results
      end

      def fetch_results
        @results ||= XXX.search(query)
      end
    end
  end
end
