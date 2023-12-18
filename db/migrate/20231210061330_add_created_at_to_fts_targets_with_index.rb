# For auto load
FullTextSearch::Migration

class AddCreatedAtToFtsTargetsWithIndex < ActiveRecord::Migration[5.2]
  def up
    return if !table_exists?(:fts_targets)

    add_column :fts_targets, :created_at, :timestamp

    ActiveRecord::Base.transaction do
      update_created_at_using_last_modified_at
      update_created_at_using_created_on
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

  class FtsTarget < ActiveRecord::Base
  end

  class FtsType < ActiveRecord::Base
  end

  def update_created_at_using_last_modified_at
    types = ['Attachment', 'Change', 'Changeset', 'CustomValue', 'Document', 'Journal', 'News']

    FtsType.where(name: types).pluck(:id).each do |type_id|
      FtsTarget.where(source_type_id: type_id).in_batches do |targets|
        targets.update_all('created_at = last_modified_at')
      end
    end
  end

  def update_created_at_using_created_on
    types = ['Issue', 'Message', 'Project', 'WikiPage']

    types.each do |type_name|
      type = FtsType.find_by(name: type_name)
      return unless type

      table_name = type.name.underscore.pluralize
      FtsTarget.where(source_type_id: type.id).in_batches do |targets|
        tmp_source_model = Class.new(ActiveRecord::Base) { self.table_name = table_name }
        source_model_with_created_on = tmp_source_model.where(id: targets.select(:source_id))
                                                       .pluck(:id, :created_on)
                                                       .to_h
        targets.each do |target|
          target.update(created_at: source_model_with_created_on[target.source_id])
        end
      end
    end
  end
end
