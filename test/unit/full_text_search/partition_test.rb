require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class PartitionTest < ActiveSupport::TestCase
    include PrettyInspectable

    fixtures :projects
    fixtures :users

    def setup
      unless Partition.partitioned?
        skip("fts_targets isn't partitioned: #{Partition.requirements_message}")
      end
      Partition.send(:ensured_years).clear
      Partition.send(:enqueued_years).clear

      @future_year = Date.current.year + 10
    end

    def test_ensure_created
      assert_equal(false, partition_exist?(@future_year))
      assert_equal(:created, Partition.ensure_created(@future_year))
      assert_equal(true, partition_exist?(@future_year))
    end

    def test_ensure_created_existing
      assert_equal(:created, Partition.ensure_created(@future_year))
      assert_equal(:exist, Partition.ensure_created(@future_year))
    end

    def test_ensure_created_moves_the_default_records
      registered_at = Time.zone.local(@future_year, 10, 10)
      data = {
        source_id: 99999,
        source_type_id: Type.issue.id,
        project_id: 1,
        title: "Partition test",
        content: "Partition test content",
        last_modified_at: registered_at,
        registered_at: registered_at,
      }
      insert_data_to_default_partition(data)
      Partition.ensure_created(@future_year)
      assert_equal(true, partition_exist?(@future_year))

      result = connection.select_values(<<~SQL)
SELECT source_id
  FROM fts_targets_#{@future_year}
      SQL
      assert_equal([99999], result)
    end

    def test_ensure_created_covered
      assert_equal(:covered, Partition.ensure_created(1970))
    end

    def test_save_hook
      registered_at = Time.zone.local(@future_year, 10, 10)
      data = {
        source_id: 99999,
        source_type_id: Type.issue.id,
        project_id: 1,
        title: "Partition test",
        content: "Partition test content",
        last_modified_at: registered_at,
        registered_at: registered_at,
      }
      Target.create(data)

      assert_equal(true, partition_exist?(@future_year))
      result = connection.select_values(<<~SQL)
SELECT source_id
  FROM fts_targets_#{@future_year}
      SQL
      assert_equal([99999], result)
    end

    private
    def connection
      ActiveRecord::Base.connection
    end

    def partition_exist?(year)
      connection.data_source_exists?("fts_targets_#{year}")
    end

    def insert_data_to_default_partition(data)
      columns = data.keys
      values = data.values.collect do |value|
        connection.quote(value)
      end
      connection.execute(<<~SQL)
INSERT INTO fts_targets_default (#{columns.join(",")})
VALUES (#{values.join(",")});
      SQL
    end
  end

  class NotPartitionedTest < ActiveSupport::TestCase
    def setup
      skip("fts_targets is partitioned") if Partition.partitioned?
      @future_year = Date.current.year + 10
    end

    def test_ensure_created
      assert_equal(false, Partition.ensure_created(@future_year))
    end
  end
end
