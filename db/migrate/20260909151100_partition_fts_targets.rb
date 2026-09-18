# For auto load
FullTextSearch::Migration

class PartitionFtsTargets < ActiveRecord::Migration[6.1]
  TABLE_NAME = "fts_targets"
  WORK_TABLE_NAME = "fts_targets_new"

  def up
    return if Redmine::Database.mysql?

    execute(<<~SQL)
CREATE TABLE #{WORK_TABLE_NAME} (
  LIKE #{TABLE_NAME}
    INCLUDING DEFAULTS
    INCLUDING CONSTRAINTS
) PARTITION BY RANGE (registered_at);
    SQL

    # Create the partitions.
    current_year = Date.current.year
    first_year = oldest_year || current_year
    # Before oldest_year, use a single partition.
    execute(<<~SQL)
CREATE TABLE #{TABLE_NAME}_past
PARTITION OF #{WORK_TABLE_NAME}
  FOR VALUES FROM (MINVALUE)
             TO ('#{first_year}-01-01');
    SQL
    # Partitions by year.
    (first_year..current_year).each do |year|
      execute(<<~SQL)
CREATE TABLE #{TABLE_NAME}_#{year}
PARTITION OF #{WORK_TABLE_NAME}
  FOR VALUES FROM ('#{year}-01-01')
             TO ('#{year + 1}-01-01');
      SQL
    end
    # Default settings in case of abnormal data.
    execute(<<~SQL)
CREATE TABLE #{TABLE_NAME}_default
PARTITION OF #{WORK_TABLE_NAME}
  DEFAULT;
    SQL

    load_data
    take_over_sequence
    replace_table
    execute(<<~SQL)
CREATE UNIQUE INDEX index_fts_targets_on_source_id_and_source_type_id
  ON #{TABLE_NAME} (source_id, source_type_id, registered_at);
CREATE UNIQUE INDEX index_fts_targets_on_id_and_registered_at
  ON #{TABLE_NAME} (id, registered_at);
    SQL
    create_pgroonga_index
    execute("SELECT pgroonga_command('plugin_register', ARRAY['name', 'sharding']);")
  end

  def down
    return if Redmine::Database.mysql?

    execute(<<~SQL)
CREATE TABLE #{WORK_TABLE_NAME} (
  LIKE #{TABLE_NAME}
    INCLUDING DEFAULTS
    INCLUDING CONSTRAINTS
);
    SQL
    load_data
    take_over_sequence
    replace_table
    execute(<<~SQL)
ALTER TABLE #{TABLE_NAME} ADD PRIMARY KEY (id);
CREATE UNIQUE INDEX index_fts_targets_on_source_id_and_source_type_id
    ON #{TABLE_NAME} (source_id, source_type_id);
    SQL
    create_pgroonga_index
  end

  private
  def oldest_year
    year = select_value(<<~SQL)
SELECT EXTRACT(YEAR FROM LEAST(
         (SELECT MIN(registered_at) FROM #{TABLE_NAME}),
         (SELECT MIN(created_on) FROM projects),
         (SELECT MIN(committed_on) FROM changesets)
       ));
    SQL
    return nil unless year
    # Since Redmine was released in 2006,
    # set the oldest year to 2006.
    [year.to_i, 2006].max
  end

  def load_data
    execute("INSERT INTO #{WORK_TABLE_NAME} SELECT * FROM #{TABLE_NAME};")
  end

  def serial_sequence_name
    select_value("SELECT pg_get_serial_sequence(#{quote(TABLE_NAME)}, 'id');")
  end

  def take_over_sequence
    sequence_name = serial_sequence_name
    execute(<<~SQL)
ALTER TABLE #{WORK_TABLE_NAME}
  ALTER COLUMN id
  SET DEFAULT nextval(#{quote(sequence_name)}::regclass);
ALTER SEQUENCE #{sequence_name} OWNED BY #{WORK_TABLE_NAME}.id;
    SQL
  end

  def replace_table
    execute("DROP TABLE #{TABLE_NAME}")
    execute("ALTER TABLE #{WORK_TABLE_NAME} RENAME TO #{TABLE_NAME}")
  end

  def create_pgroonga_index
    execute(<<~SQL)
CREATE INDEX fts_targets_index_pgroonga
  ON #{TABLE_NAME}
  USING pgroonga (
    id,
    source_id,
    source_type_id,
    project_id,
    container_id,
    container_type_id,
    custom_field_id,
    is_private,
    is_container_private,
    last_modified_at,
    registered_at,
    title,
    content,
    tag_ids
  )
  WITH (normalizer='NormalizerNFKC121');
    SQL
  end
end
