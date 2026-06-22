module FullTextSearch
  class SemanticSearcher < Searcher
    K = 50

    private
    def semantic?
      true
    end

    def use_slices?
      false
    end

    def query
      nil
    end

    def match_columns
      []
    end

    def knn_expression
      query = Groonga::Client::ScriptSyntax.format_string(@request.query)
      %Q[language_model_knn(content, #{query}, {"k": #{K}})]
    end

    def filter
      return "false" if @request.query.blank?

      visibility = super
      return "false" unless visibility

      "#{knn_expression} && (#{visibility})"
    end

    def sort_keys
      ["-#{knn_expression}"]
    end
  end
end
