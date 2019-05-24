migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class AddMissingIndexesToSearcherRecords < migration
  def change
    if Redmine::Database.mysql?
      add_index(:searcher_records, "short_comments", type: "fulltext")
      add_index(:searcher_records, "long_comments", type: "fulltext")
    end
  end
end
