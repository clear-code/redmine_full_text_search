module FullTextSearch
  module PGroonga
    extend ActiveSupport::Concern

    module ClassMethods
      def select(command)
        sql = build_sql(command)
        raw_response = connection.select_value(sql)
        Groonga::Client::Response.parse(command, raw_response)
      end

      def build_expand_query_sql_part(query)
        [
          "pgroonga_query_expand(?, ?, ?, ?)",
          [
            table_name,
            source_column_name,
            destination_column_name,
            query,
          ],
        ]
      end

      def time_offset
        @time_offset ||= compute_time_offset
      end

      def groonga_version
        # Ensure loading PGroonga
        connection.select_rows(<<-SQL)
SELECT pgroonga_command('status');
        SQL
        connection.select_rows(<<-SQL)[0][0]
SHOW pgroonga.libgroonga_version;
        SQL
      end

      def multiple_column_unique_key_update_is_supported?
        true
      end

      private
      def build_sql(command)
        arguments = []
        placeholders = []
        command["table"] = "pgroonga_table_name('#{pgroonga_index_name}')"
        if command["filter"].present?
          command["filter"] += " && pgroonga_tuple_is_alive(ctid)"
        else
          command["filter"] = "pgroonga_tuple_is_alive(ctid)"
        end
        command.arguments.each do |name, value|
          next if value.blank?
          next if name == :table
          placeholders << "?"
          arguments << name
          if name == :query
            expand_query_sql_part =
              FtsQueryExpansion.build_expand_query_sql_part(value)
            placeholders << expand_query_sql_part[0]
            arguments.concat(expand_query_sql_part[1])
          else
            placeholders << "?"
            arguments << value
          end
        end
        sql_template = <<-SELECT
SELECT pgroonga_command(?,
  ARRAY[
    'table', #{command["table"]},
    #{placeholders.join(", ")}
  ]
)
        SELECT
        sanitize_sql([sql_template,
                      command.command_name,
                      *arguments])
      end

      def compute_time_offset
        utc_offset = connection.select_value(<<-SQL)
SELECT utc_offset
  FROM pg_timezone_names
 WHERE name = current_setting('timezone')
        SQL
        case utc_offset
        when /\A(-)?(\d+):(\d+):(\d+)\z/
          minus = $1
          hours = Integer($2, 10)
          minutes = Integer($3, 10)
          seconds = Integer($4, 10)
          offset = (hours * 60 * 60) + (minutes * 60) + seconds
          offset = -offset if minus == "-"
          offset - Time.now.utc_offset
        else
          raise "Invalid time offset value: #{utc_offset.inspect}"
        end
      end
    end
  end
end
