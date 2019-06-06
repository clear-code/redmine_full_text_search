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

      def time_offset
        @time_offset ||= compute_time_offset
      end

      private
      def build_sql(command)
        arguments = [command.command_name]
        command["table"] = table_name
        command.arguments.each do |name, value|
          next if value.blank?
          arguments << name
          arguments << value
        end
        placeholders = (["?"] * arguments.size).join(", ")
        sql_template = "SELECT mroonga_command(#{placeholders})"
        sanitize_sql([sql_template, *arguments])
      end

      def compute_time_offset
        -Time.now.utc_offset
      end
    end
  end
end
