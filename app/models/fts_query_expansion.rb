class FtsQueryExpansion < ActiveRecord::Base
  case connection_config[:adapter]
  when "postgresql"
    require_dependency "full_text_search/pgroonga"
    include FullTextSearch::PGroonga
  when "mysql2"
    require_dependency "full_text_search/mroonga"
    include FullTextSearch::Mroonga
  end

  class << self
    def source_column_name
      "source"
    end

    def destination_column_name
      "destination"
    end

    def expand_query(query)
      sql_part = build_expand_query_sql_part(query)
      placeholder = sql_part[0]
      arguments = sql_part[1]
      sql_template = <<-SELECT
SELECT #{placeholder}
      SELECT
      sql = sanitize_sql([sql_template, *arguments])
      connection.select_value(sql)
    end
  end

  validates_presence_of :source
  validates_presence_of :destination
end
