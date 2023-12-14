# For auto load
FullTextSearch::Migration

class AddCreatedAtToFtsTargetsWithIndex < ActiveRecord::Migration[5.2]
  def up
    add_column :fts_targets, :created_at, :timestamp

    ActiveRecord::Base.transaction do
      update_created_at_for_changes
      update_created_at_using_last_modified_at
      update_created_at_using_created_on("Issue", "issues")
      update_created_at_using_created_on("Message", "messages")
      update_created_at_using_created_on("Project", "projects")
      update_created_at_using_created_on("WikiPage", "wiki_pages")
    end

    if Redmine::Database.mysql?
      add_index :fts_targets, :created_at
    else
      remove_index :fts_targets, name: "fts_targets_index_pgroonga"
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

  def down
    if Redmine::Database.mysql?
      remove_index :fts_targets, :created_at
    else
      remove_index :fts_targets, name: "fts_targets_index_pgroonga"
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
                 :title,
                 :content,
                 :tag_ids],
                using: "PGroonga",
                with: "normalizer = 'NormalizerNFKC121'",
                name: "fts_targets_index_pgroonga"
    end

    remove_column :fts_targets, :created_at
  end

  private

  def update_created_at_for_changes
    execute <<-SQL
      UPDATE fts_targets
      SET created_at = (SELECT committed_on FROM changesets WHERE changesets.id = (SELECT changeset_id FROM changes WHERE changes.id = fts_targets.source_id))
      WHERE fts_targets.source_type_id = (SELECT id FROM fts_types WHERE name = 'Change')
    SQL
  end

  def update_created_at_using_last_modified_at
    execute <<-SQL
      UPDATE fts_targets
      SET created_at = last_modified_at
      WHERE fts_targets.source_type_id IN (SELECT id FROM fts_types WHERE name IN ('CustomValue', 'Attachment', 'Changeset', 'Document', 'Journal', 'News'));
    SQL
  end

  def update_created_at_using_created_on(type_name, table_name)
    execute <<-SQL
      UPDATE fts_targets
      SET created_at = (SELECT created_on FROM #{table_name} WHERE #{table_name}.id = fts_targets.source_id)
      WHERE fts_targets.source_type_id = (SELECT id FROM fts_types WHERE name = '#{type_name}')
    SQL
  end
end
