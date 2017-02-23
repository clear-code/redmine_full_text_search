module FullTextSearch
  module Fetcher
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
      # only keep ids now that results are sorted
      ret.map! {|scope, r| [scope, r.last]}
      ret
    end
  end
end
