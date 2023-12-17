# For auto load
FullTextSearch::Migration

class AddCreatedAtToFtsTargetsWithIndex < ActiveRecord::Migration[5.2]
  def up
    return if !table_exists?(:fts_targets)

    add_column :fts_targets, :created_at, :timestamp

    ActiveRecord::Base.transaction do
      update_created_at_for_changes
      update_created_at_using_last_modified_at
      update_created_at_using_created_on('Issue', 'issues')
      update_created_at_using_created_on('Message', 'messages')
      update_created_at_using_created_on('Project', 'projects')
      update_created_at_using_created_on('WikiPage', 'wiki_pages')
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
    return if !table_exists?(:fts_targets)

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

  class TmpTarget < ActiveRecord::Base
    self.table_name = 'fts_targets'
  end

  class TmpType < ActiveRecord::Base
    self.table_name = 'fts_types'
  end

  class TmpChange < ActiveRecord::Base
    self.table_name = 'changes'
  end

  class TmpChangeset < ActiveRecord::Base
    self.table_name = 'changesets'
  end

  def update_created_at_for_changes
    change_type = TmpType.find_by(name: 'Change')
    return unless change_type

    TmpTarget.where(source_type_id: change_type.id).in_batches do |targets|
      targets.each do |target|
        change = TmpChange.find_by(id: target.source_id)
        changeset = TmpChangeset.find_by(id: change.changeset_id)
        target.update(created_at: changeset.committed_on)
      end
    end
  end

  def update_created_at_using_last_modified_at
    TmpType.where(name: ['CustomValue', 'Attachment', 'Changeset', 'Document', 'Journal', 'News']).pluck(:id).each do |type_id|
      TmpTarget.where(source_type_id: type_id).in_batches do |targets|
        targets.update_all('created_at = last_modified_at')
      end
    end
  end

  def update_created_at_using_created_on(type_name, table_name)
    type = TmpType.find_by(name: type_name)
    return unless type

    tmp_source_model = Class.new(ActiveRecord::Base) { self.table_name = table_name }
    TmpTarget.where(source_type_id: type.id).in_batches do |targets|
      targets.each do |target|
        source_record = tmp_source_model.find_by(id: target.source_id)
        target.update(created_at: source_record.created_on)
      end
    end
  end
end
