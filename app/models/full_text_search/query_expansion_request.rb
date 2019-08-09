module FullTextSearch
  class QueryExpansionRequest
    include ActiveModel::Model
    extend ActiveModel::Naming

    attr_writer :query

    def to_params
      {
        "query" => query,
      }
    end

    def query
      (@query || "").strip
    end
  end
end
