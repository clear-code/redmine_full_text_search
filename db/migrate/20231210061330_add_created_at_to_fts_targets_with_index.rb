# For auto load
FullTextSearch::Migration

class AddCreatedAtToFtsTargetsWithIndex < ActiveRecord::Migration[6.1]
  def change
    return if reverting?

    add_column :fts_targets, :created_at, :timestamp if !column_exists?(:fts_targets, :created_at)

    if Redmine::Database.mysql?
      return if index_exists?(:fts_targets, :created_at)
      add_index :fts_targets, :created_at
    else
      remove_index :fts_targets, name: "fts_targets_index_pgroonga" if index_name_exists?(:fts_targets, "fts_targets_index_pgroonga")
      add_index :fts_targets,
                [:id,
                 :source_id,
                 :source_type_id,
                 :project_id,
                 :container_id,
                 :container_type_id,
                 :custom_field_id,
                 :is_private,
                 :last_modified_at,
                 :created_at,
                 :title,
                 :content,
                 :tag_ids],
                using: "PGroonga",
                with: "normalizer = 'NormalizerNFKC121'",
                name: "fts_targets_index_pgroonga"
    end
  end
end
