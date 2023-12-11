# For auto load
FullTextSearch::Migration

class AddCreatedAtToFtsTargetsWithIndex < ActiveRecord::Migration[5.2]
  def up
    add_column :fts_targets, :created_at, :timestamp

    ActiveRecord::Base.transaction do
      update_created_at_for_changes
      update_created_at_for_custom_values
      update_created_at("Attachment", "attachments", "created_on")
      update_created_at("Changeset", "changesets", "committed_on")
      update_created_at("Document", "documents", "created_on")
      update_created_at("Issue", "issues", "created_on")
      update_created_at("Journal", "journals", "created_on")
      update_created_at("Message", "messages", "created_on")
      update_created_at("News", "news", "created_on")
      update_created_at("Project", "projects", "created_on")
      update_created_at("WikiPage", "wiki_pages", "created_on")
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

  def update_created_at_for_custom_values
    execute <<-SQL
      UPDATE fts_targets
      SET created_at = (SELECT created_on FROM issues WHERE issues.id = (SELECT customized_id FROM custom_values WHERE custom_values.id = fts_targets.source_id AND customized_type = 'Issue'))
      WHERE fts_targets.source_type_id = (SELECT id FROM fts_types WHERE name = 'CustomValue') AND
            EXISTS (SELECT 1 FROM custom_values WHERE custom_values.id = fts_targets.source_id AND customized_type = 'Issue')
    SQL

    execute <<-SQL
      UPDATE fts_targets
      SET created_at = (SELECT created_on FROM projects WHERE projects.id = (SELECT customized_id FROM custom_values WHERE custom_values.id = fts_targets.source_id AND customized_type = 'Project'))
      WHERE fts_targets.source_type_id = (SELECT id FROM fts_types WHERE name = 'CustomValue') AND
            EXISTS (SELECT 1 FROM custom_values WHERE custom_values.id = fts_targets.source_id AND customized_type = 'Project')
    SQL
  end

  def update_created_at(type_name, table_name, timestamp_column)
    execute <<-SQL
      UPDATE fts_targets
      SET created_at = (SELECT #{timestamp_column} FROM #{table_name} WHERE #{table_name}.id = fts_targets.source_id)
      WHERE fts_targets.source_type_id = (SELECT id FROM fts_types WHERE name = '#{type_name}')
    SQL
  end
end
