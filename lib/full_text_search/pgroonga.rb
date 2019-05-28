module FullTextSearch
  module PGroonga
    extend ActiveSupport::Concern

    module ClassMethods
      def select(command)
        sql = build_sql(command)
        raw_response = nil
        ActiveSupport::Notifications.instrument("groonga.search", sql: sql) do
          raw_response = connection.select_value(sql)
        end
        response = Groonga::Client::Response.parse(command, raw_response)
        adjust_groonga_response!(response)
        response
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
        -Time.now.utc_offset
      end

      def adjust_groonga_response!(response)
        response.records.each do |record|
          original_type = record["original_type"]
          next unless original_type
          record["original_type"] = adjust_original_type(original_type)
        end
        response.drilldowns.each do |drilldown|
          next unless drilldown.key == "original_type"
          drilldown.records.each do |record|
            record["_key"] = adjust_original_type(record["_key"])
          end
        end
      end

      def adjust_original_type(original_type)
        case original_type
        when "wikipage"
          "WikiPage"
        else
          original_type.camelize
        end
      end
    end
  end
end
