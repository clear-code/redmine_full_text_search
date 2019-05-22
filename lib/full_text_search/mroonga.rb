module FullTextSearch
  module Mroonga
    extend ActiveSupport::Concern

    module ClassMethods
      def select(command)
        sql = build_sql(command)
        raw_response = nil
        ActiveSupport::Notifications.instrument("groonga.search", sql: sql) do
          raw_response = connection.select_value(sql)
        end
        response_class = Groonga::Client::Response.find(command.command_name)
        header = [0, 0, 0]
        body = JSON.parse(raw_response)
        response = response_class.new(command, header, body)
        response.raw = "[#{header.to_json}, #{raw_response}]"
        response
      end

      private
      def build_sql(command)
        arguments = [command.command_name]
        command["table"] = table_name
        command.arguments.each do |name, value|
          next if value.blank?
          arguments << name
          arguments << value.to_s
        end
        placeholders = (["?"] * arguments.size).join(", ")
        sql_template = "SELECT mroonga_command(#{placeholders})"
        ActiveRecord::Base.sanitize_sql([sql_template, *arguments])
      end
    end
  end
end
