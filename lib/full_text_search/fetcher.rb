module FullTextSearch
  module Fetcher
    # Returns the results for the given offset and limit
    def results(offset, limit)
      result_ids_to_load = result_ids[offset, limit] || []

      results_by_scope = Hash.new {|h, k| h[k] = [] }
      result_ids_to_load.group_by(&:first).each do |scope, scope_and_ids|
        klass = scope.singularize.camelcase.constantize
        results_by_scope[scope] += klass.search_results_from_ids(scope_and_ids.map(&:last))
      end

      result_ids_to_load.map do |scope, score, id|
        [results_by_scope[scope].detect {|record| record.id == id }, score]
      end.compact
    end

    # Overwrite Redmine::Search::Fetcher#load_result_ids to set order type
    def load_result_ids
      ret = []
      # get all the results ranks and ids
      @scope.each do |scope|
        klass = scope.singularize.camelcase.constantize
        ranks_and_ids_in_scope = klass.search_result_ranks_and_ids(@tokens, User.current, @projects, @options)
        ret += ranks_and_ids_in_scope.map {|rs| [scope, rs]}
      end
      # sort results, higher rank and id first
      # a.last # => [score, id]
      if @options[:params][:order_type] == "desc"
        ret.sort! {|a, b| b.last <=> a.last }
      else
        ret.sort! {|a, b| a.last <=> b.last }
      end
      # [[scope, score, id], ...]
      ret.map! {|scope, r| [scope, r].flatten }
      ret
    end
  end
end
