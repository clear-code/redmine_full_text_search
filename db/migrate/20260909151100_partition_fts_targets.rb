# For auto load
FullTextSearch::Migration

class PartitionFtsTargets < ActiveRecord::Migration[6.1]
  def up
    return unless table_exists?(:fts_targets)
    return if Redmine::Database.mysql?

    execute(<<~SQL)
CREATE TABLE fts_targets_new (
  id bigint NOT NULL,
  source_id integer NOT NULL,
  source_type_id integer NOT NULL,
  project_id integer NOT NULL,
  container_id integer,
  container_type_id integer,
  custom_field_id integer,
  is_private boolean,
  last_modified_at timestamp without time zone,
  title text,
  content text,
  tag_ids integer[],
  registered_at timestamp without time zone
) PARTITION BY RANGE (registered_at);
SQL

    period = select_one(<<~SQL)
SELECT
  MIN(registered_at) AS min_registered_at,
  MAX(registered_at) AS max_registered_at
  FROM fts_targets;
SQL

    min_registered_at = period["min_registered_at"]
    max_registered_at = period["max_registered_at"]

    if min_registered_at.nil? || max_registered_at.nil?
      current_year = Date.today.year
      next_year = current_year + 1
      execute <<~SQL
CREATE TABLE fts_targets_new_#{current_year}
PARTITION OF fts_targets_new
  FOR VALUES FROM ('#{current_year}-01-01')
             TO ('#{next_year}-01-01');
SQL
    else
      (
        min_registered_at.to_date.year..
        max_registered_at.to_date.year
      ).each do |year|
        next_year = year + 1
        execute <<~SQL
CREATE TABLE fts_targets_new_#{year}
PARTITION OF fts_targets_new
  FOR VALUES FROM ('#{year}-01-01')
             TO ('#{next_year}-01-01');
SQL
      end
    end

    execute(<<~SQL)
INSERT INTO fts_targets_new
     SELECT *
       FROM fts_targets;
SQL

    execute("ALTER TABLE fts_targets RENAME_TO fts_targets_old")
    execute("ALTER TABLE fts_targets_new RENAME_TO fts_targets")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
