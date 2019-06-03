migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class DropSearcherRecords < migration
  def change
    reversible do |d|
      d.up do
        drop_table :searcher_records
      end
      d.down do
        create_table :searcher_records do
        end
      end
    end
  end
end
