module FullTextSearch
  class Partition
    MIGRATION_VERSION = 20260909151100

    # To use "logical_select", the following features are required.
    # * `slices`
    # * the dynamic columns of the `output` stage
    # * `query_flags`
    # These features were added in the following version.
    GROONGA_REQUIRED_VERSION = "16.1.1"

    # "pgroonga_physical_table_names" is added in this version.
    # It's needed to specify the Groonga table of each partition.
    PGROONGA_REQUIRED_VERSION = "4.0.9"

    class << self
      def available?
        return false unless Redmine::Database.postgresql?
        return false unless physical_table_names_available?
        return false unless ensure_sharding_plugin_registered
        logical_select_features_are_supported?
      end

      def table_name
        Target.table_name.to_s
      end

      def partitioned?
        return false unless Redmine::Database.postgresql?
        if @partition.nil?
          @partition = (connection.select_value(<<~SQL) == "p")
SELECT relkind
  FROM pg_class
 WHERE oid = to_regclass(#{connection.quote(table_name)});
          SQL
        end
        @partition
      end

      def ensure_sharding_plugin_registered
        return true if @sharding_plugin_registered

        response = connection.select_value(<<~SQL)
SELECT pgroonga_command('plugin_register', ARRAY['name', 'sharding']);
        SQL
        header, body = JSON.parse(response)
        @sharding_plugin_registered = (header[0].zero? && body == true)
      rescue ActiveRecord::StatementInvalid, JSON::ParserError, TypeError
        false
      end

      def logical_select_features_are_supported?
        if @logical_select_features_are_supported.nil?
          @logical_select_features_are_supported =
            (Gem::Version.new(Target.groonga_version) >=
             Gem::Version.new(GROONGA_REQUIRED_VERSION))
        end
        @logical_select_features_are_supported
      end

      def requirements_message
        "partitioning requires " +
          "Groonga #{GROONGA_REQUIRED_VERSION} or later and " +
          "PGroonga #{PGROONGA_REQUIRED_VERSION} or later"
      end

      private
      def physical_table_names_available?
        connection.select_value(<<~SQL).present?
SELECT to_regprocedure('pgroonga_physical_table_names(text, text)');
        SQL
      end

      def connection
        ActiveRecord::Base.connection
      end
    end
  end
end
