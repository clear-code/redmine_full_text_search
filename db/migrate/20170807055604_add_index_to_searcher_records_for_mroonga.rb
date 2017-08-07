class AddIndexToSearcherRecordsForMroonga < ActiveRecord::Migration
  def change
    if Redmine::Database.mysql?
      add_index(:searcher_records, "original_type", name: "index_searcher_records_on_original_type_perfect_matching")
      add_index(:searcher_records, "project_id")
    end
  end
end
