# For auto load
FullTextSearch::Migration

class AddPrivateNotesToFtsTargets < ActiveRecord::Migration[6.1]
  def up
    return unless table_exists?(:fts_targets)

    add_column :fts_targets, :private_notes, :boolean

    if Redmine::Database.mysql?
      split_journal_private_flags
      add_index :fts_targets, :private_notes
    else
      remove_index :fts_targets, name: "fts_targets_index_pgroonga"
      split_journal_private_flags
      create_pgroonga_index([:id,
                             :source_id,
                             :source_type_id,
                             :project_id,
                             :container_id,
                             :container_type_id,
                             :custom_field_id,
                             :is_private,
                             :private_notes,
                             :last_modified_at,
                             :registered_at,
                             :title,
                             :content,
                             :tag_ids])
    end
  end

  def down
    return unless table_exists?(:fts_targets)

    if Redmine::Database.mysql?
      remove_index :fts_targets, :private_notes
      merge_journal_private_flags
    else
      remove_index :fts_targets, name: "fts_targets_index_pgroonga"
      merge_journal_private_flags
      create_pgroonga_index([:id,
                             :source_id,
                             :source_type_id,
                             :project_id,
                             :container_id,
                             :container_type_id,
                             :custom_field_id,
                             :is_private,
                             :last_modified_at,
                             :registered_at,
                             :title,
                             :content,
                             :tag_ids])
    end

    remove_column :fts_targets, :private_notes
  end

  private
  class FtsType < ActiveRecord::Base
  end

  def split_journal_private_flags
    journal_type = FtsType.find_by(name: "Journal")
    return unless journal_type

    if Redmine::Database.mysql?
      execute(<<-SQL)
UPDATE fts_targets
JOIN journals ON journals.id = fts_targets.source_id
JOIN issues
  ON journals.journalized_type = 'Issue' AND
     issues.id = journals.journalized_id
SET fts_targets.is_private = issues.is_private,
    fts_targets.private_notes = journals.private_notes
WHERE fts_targets.source_type_id = #{journal_type.id}
      SQL
    else
      execute(<<-SQL)
UPDATE fts_targets
SET is_private = issues.is_private,
    private_notes = journals.private_notes
FROM journals
JOIN issues
  ON journals.journalized_type = 'Issue' AND
     issues.id = journals.journalized_id
WHERE fts_targets.source_id = journals.id
  AND fts_targets.source_type_id = #{journal_type.id}
      SQL
    end
  end

  def merge_journal_private_flags
    journal_type = FtsType.find_by(name: "Journal")
    return unless journal_type

    if Redmine::Database.mysql?
      execute(<<-SQL)
UPDATE fts_targets
JOIN journals ON journals.id = fts_targets.source_id
JOIN issues
  ON journals.journalized_type = 'Issue' AND
     issues.id = journals.journalized_id
SET fts_targets.is_private = (issues.is_private OR journals.private_notes)
WHERE fts_targets.source_type_id = #{journal_type.id}
      SQL
    else
      execute(<<-SQL)
UPDATE fts_targets
SET is_private = (issues.is_private OR journals.private_notes)
FROM journals
JOIN issues
  ON journals.journalized_type = 'Issue' AND
     issues.id = journals.journalized_id
WHERE fts_targets.source_id = journals.id
  AND fts_targets.source_type_id = #{journal_type.id}
      SQL
    end
  end

  def create_pgroonga_index(columns)
    add_index :fts_targets,
              columns,
              using: "PGroonga",
              with: "normalizer = 'NormalizerNFKC121'",
              name: "fts_targets_index_pgroonga"
  end
end
