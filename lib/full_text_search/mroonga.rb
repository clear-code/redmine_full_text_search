module FullTextSearch
  module Mroonga
    extend ActiveSupport::Concern

    module ClassMethods
      def select(command)
        sql = build_sql(command)
        now = Time.zone.now.to_f
        raw_response = connection.select_value(sql)
        elapsed_time = Time.zone.now.to_f - now
        response_class = Groonga::Client::Response.find(command.command_name)
        header = [0, now, elapsed_time]
        body = JSON.parse(raw_response)
        response = response_class.new(command, header, body)
        response.raw = "[#{header.to_json}, #{raw_response}]"
        response
      end

      def full_text_search(column, query)
        where("MATCH (#{connection.quote_column_name(column)}) " +
              "AGAINST (? IN BOOLEAN MODE)",
              query)
      end

      def build_expand_query_sql_part(query)
        [
          "mroonga_query_expand(?, ?, ?, ?) AS query",
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

      def mroonga_version
        connection.select_rows(<<-SQL)[0][1]
SHOW VARIABLES LIKE 'mroonga_version';
        SQL
      end

      def groonga_version
        connection.select_rows(<<-SQL)[0][1]
SHOW VARIABLES LIKE 'mroonga_libgroonga_version';
        SQL
      end

      def mroonga_vector_load_is_supported?
        Gem::Version.new(groonga_version) >= Gem::Version.new("9.0.5")
      end

      def multiple_column_unique_key_update_is_supported?
        Gem::Version.new(mroonga_version) >= Gem::Version.new("9.05")
      end

      private
      def build_sql(command)
        arguments = [command.command_name]
        placeholders = ["?"]
        command["table"] = table_name
        command.arguments.each do |name, value|
          next if value.blank?
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
SELECT mroonga_command(#{placeholders.join(", ")})
        SELECT
        sanitize_sql([sql_template, *arguments])
      end

      def compute_time_offset
        mysql_system_time_zone = connection.select_rows(<<-SQL)[0][1]
SHOW VARIABLES LIKE 'system_time_zone'
        SQL
        mysql_system_utc_offset = 0
        TZInfo::Timezone.all.each do |timezone|
          period = timezone.current_period
          if period.abbreviation.to_s == mysql_system_time_zone
            mysql_system_utc_offset = period.utc_offset
            break
          end
        end
        mysql_system_utc_offset - Time.now.utc_offset
      end
    end
  end
end
