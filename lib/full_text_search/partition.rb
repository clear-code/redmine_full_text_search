require_relative "migration"

module FullTextSearch
  class Partition
    class << self
      def available?
        Redmine::Database.postgresql?
      end

      def exist?
        return false unless available?
        connection.data_source_exists?(table_name)
      end

      def table_name
        Target.table_name
      end

      def table_name_old
        table_name + "_old"
      end

      def table_name_next_year
        table_name + "#{next_year}"
      end

      def next_year
        Date.current.year + 1
      end

      def year_after_next
        next_year + 1
      end

      def ensure_dropped_before_partitioning
        return false unless available?
        return false unless connection.data_source_exists?(table_name_old)
        connection.drop_table(table_name)
        true
      end

      def ensure_created_next_year_partition
        return false unless available?
        return false unless connection.data_source_exists?(table_name)
        return false unless connection.data_source_exists?(table_name_next_year)

        connection.execute <<~SQL
CREATE TABLE #{table_name_next_year}
PARTITION OF #{table_name}
  FOR VALUES FROM ('#{next_year}-01-01')
             TO ('#{year_after_next}-01-01');
SQL
SQL
      end

      private

      def connection
        ActiveRecord::Base.connection
      end
    end
  end
end
