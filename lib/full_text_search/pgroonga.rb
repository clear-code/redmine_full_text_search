module FullTextSearch
  module PGroonga
    extend ActiveSupport::Concern

    module ClassMethods
      def select(command)
        sql = build_sql(command)
        raw_response = connection.select_value(sql)
        Groonga::Client::Response.parse(command, raw_response)
      end

      def time_offset
        @time_offset ||= compute_time_offset
      end

      private
      def build_sql(command)
        arguments = []
        command["table"] = "pgroonga_table_name('#{pgroonga_index_name}')"
        if command["filter"].present?
          command["filter"] += "&& pgroonga_tuple_is_alive(ctid)"
        else
          command["filter"] = "pgroonga_tuple_is_alive(ctid)"
        end
        command.arguments.each do |name, value|
          next if value.blank?
          next if name == :table
          arguments << name
          arguments << value
        end
        placeholders = (["?"] * arguments.size).join(", ")
        sql_template = "SELECT pgroonga_command(?, ARRAY["
        sql_template << "'table', #{command["table"]}, "
        sql_template << "#{placeholders}])"
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
