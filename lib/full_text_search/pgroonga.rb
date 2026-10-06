module FullTextSearch
  module Pgroonga
    extend ActiveSupport::Concern

    module ClassMethods
      def select(command, semantic: false)
        sql = build_sql(command, semantic: semantic)
        raw_response = connection.select_value(sql)
        Groonga::Client::Response.parse(command, raw_response)
      end

      def build_select_command(arguments)
        if Partition.partitioned?
          Partition.ensure_sharding_plugin_registered
          Groonga::Command::LogicalSelect.new("logical_select", arguments)
        else
          Groonga::Command::Select.new("select", arguments)
        end
      end

      def slices_are_supported?
        if Partition.partitioned?
          Partition.logical_select_features_are_supported?
        else
          Gem::Version.new(groonga_version) >= Gem::Version.new("9.0.7")
        end
      end

      def dynamic_column_stage
        if output_stage_is_supported?
          "output"
        else
          "filtered"
        end
      end

      def full_text_search(column, query)
        where("#{connection.quote_column_name(column)} &@~ ?",
              query)
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
      def output_stage_is_supported?
        return @output_stage_is_supported unless @output_stage_is_supported.nil?
        @output_stage_is_supported = (!Partition.partitioned? || Partition.logical_select_features_are_supported?)
      end

      def build_sql(command, semantic: false)
        index_name = semantic ? SemanticIndex::INDEX_NAME : pgroonga_index_name
        arguments = []
        placeholders = []
        command["shard_key"] = "registered_at" if Partition.partitioned?
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

        if Partition.partitioned?
          tables = "pgroonga_physical_table_names('#{index_name}', 'shard')"
        else
          tables = "ARRAY['table', pgroonga_table_name('#{index_name}')]"
        end
        sql_template = <<-SELECT
SELECT pgroonga_command(?,
  #{tables} ||
  ARRAY[
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
        when /\A[-+]?PT/
          duration = ActiveSupport::Duration.parse(utc_offset)
          duration.in_seconds - Time.now.utc_offset
        else
          raise "Invalid time offset value: #{utc_offset.inspect}"
        end
      end
    end
  end
end
