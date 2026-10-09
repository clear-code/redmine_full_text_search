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

    # "n_workers" of "logical_select" is available since Groonga 16.1.1
    # but it has bugs when it's used via PGroonga. They are fixed in
    # the following versions.
    GROONGA_PARALLEL_REQUIRED_VERSION = "16.1.3"
    PGROONGA_PARALLEL_REQUIRED_VERSION = "4.1.0"

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

      def parallel_logical_select_is_supported?
        if @parallel_logical_select_is_supported.nil?
          @parallel_logical_select_is_supported =
            (Gem::Version.new(Target.groonga_version) >=
             Gem::Version.new(GROONGA_PARALLEL_REQUIRED_VERSION) &&
             Gem::Version.new(Target.pgroonga_version) >=
             Gem::Version.new(PGROONGA_PARALLEL_REQUIRED_VERSION))
        end
        @parallel_logical_select_is_supported
      end

      def ensure_created(year)
        return false unless partitioned?
        return :exist if connection.data_source_exists?(partition_name(year))
        create(year)
      rescue ActiveRecord::StatementInvalid => error
        # There may be cases where you try to create a partition
        # that is older than the oldest partition.
        # In that case, it will be treated as a warning.
        # This is because the `past` partition handles older data.
        raise unless error.cause.is_a?(PG::InvalidObjectDefinition)
        Rails.logger.warn("[full-text-search][partition][create] " +
                          "failed to create the partition for #{year}: #{error}")
        :covered
      end

      def ensure_created_later(year)
        return false unless partitioned?
        return :exist if ensured_years.member?(year)
        if connection.data_source_exists?(partition_name(year))
          ensured_years.add(year)
          enqueued_years.delete(year)
          return :exist
        end
        return :enqueued if enqueued_years.member?(year)
        CreatePartitionJob.perform_later(year)
        enqueued_years.add(year)
        :enqueued
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

      def partition_name(year)
        "#{table_name}_#{year}"
      end

      def default_partition_name
        "#{table_name}_default"
      end

      def ensured_years
        @ensured_years ||= Concurrent::Set.new
      end

      def enqueued_years
        @enqueued_years ||= Concurrent::Set.new
      end

      def create(year)
        name = partition_name(year)
        connection.transaction(requires_new: true) do
          # Lock the table so that no record is inserted into the
          # default partition after moving the records.
          connection.execute("LOCK TABLE #{table_name} IN ACCESS EXCLUSIVE MODE;")
          next :exist if connection.data_source_exists?(name)

          connection.execute(<<~SQL)
CREATE TABLE #{name} (
  LIKE #{table_name}
    INCLUDING DEFAULTS
    INCLUDING CONSTRAINTS
);
          SQL

          # Move the records because having them in the default table causes an error.
          move_default_records(year)

          connection.execute(<<~SQL)
ALTER TABLE #{table_name}
ATTACH PARTITION #{name}
FOR VALUES FROM ('#{year}-01-01') TO ('#{year + 1}-01-01');
          SQL
          :created
        end
      end

      def move_default_records(year)
        connection.execute(<<~SQL)
WITH moved AS (
  DELETE FROM #{default_partition_name}
        WHERE registered_at >= '#{year}-01-01'
          AND registered_at < '#{year + 1}-01-01'
    RETURNING *
)
INSERT INTO #{partition_name(year)}
SELECT * FROM moved;
        SQL
      end

      def connection
        ActiveRecord::Base.connection
      end
    end
  end
end
