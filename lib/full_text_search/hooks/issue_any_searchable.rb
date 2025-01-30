module FullTextSearch
  module Hooks
    module IssueAnySearchable
      def sql_for_any_searchable_field(field, operator, value)
        # TODO: Implement AND searches across multiple fields.
        super(field, operator, value)
      end
    end
  end
end
