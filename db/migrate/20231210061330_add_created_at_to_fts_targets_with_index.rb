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

  class Issue < ActiveRecord::Base
  end

  class Message < ActiveRecord::Base
  end

  class Project < ActiveRecord::Base
  end

  class WikiPage < ActiveRecord::Base
  end

  def update_created_at_using_last_modified_at
    types = ['Attachment', 'Change', 'Changeset', 'CustomValue', 'Document', 'Journal', 'News']

    FtsTarget.where(source_type_id: FtsType.where(name: types).select(:id))
             .update_all(created_at: FtsTarget.arel_table[:last_modified_at])
  end

  def update_created_at_using_created_on
    types = ['Issue', 'Message', 'Project', 'WikiPage']

    types.each do |type_name|
      source_table = type_name.constantize.arel_table
      fts_targets_table = FtsTarget.arel_table

      subquery_for_created_on = source_table.project(source_table[:created_on])
                                            .where(source_table[:id].eq(fts_targets_table[:source_id]))
                                            .to_sql

      FtsTarget.where(source_type_id: FtsType.where(name: type_name).select(:id))
               .update_all("created_at = (#{subquery_for_created_on})")
    end
  end
end
