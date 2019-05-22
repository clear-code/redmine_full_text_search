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
        Groonga::Client::Response.parse(command.command_name, raw_response)
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
          return if value.blank?
          arguments << name
          arguments << value
        end
        placeholders = (["?"] * arguments.size).join(", ")
        sql_template = "SELECT pgroonga_command(?, ARRAY[#{placeholders}])"
        ActiveRecord::Base.sanitize_sql([sql_template,
                                         command.command_name,
                                         *arguments])
      end
    end
  end
end
