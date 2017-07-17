module FullTextSearch
  class SearcherRecord < ActiveRecord::Base
    class << self
      def from_record(record_hash)
        h = record_hash.dup
        h.delete("_id")
        h.delete("ctid")
        new(h)
      end

      def target_columns
        %i[
          name
          identifier
          description
          title
          summary
          subject
          comments
          content
          notes
          text
          value
          filename
        ]
      end
    end

    def similar_search(limit: 10)
      # TODO
    end
  end
end
