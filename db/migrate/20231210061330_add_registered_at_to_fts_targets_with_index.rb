# For auto load
FullTextSearch::Migration

class AddRegisteredAtToFtsTargetsWithIndex < ActiveRecord::Migration[5.2]
  def up
    return if !table_exists?(:fts_targets)

    add_column :fts_targets, :registered_at, :timestamp

    ActiveRecord::Base.transaction do
      update_registered_at_using_last_modified_at
      update_registered_at_using_created_on
    end

    if Redmine::Database.mysql?
      add_index :fts_targets, :registered_at
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
                 :registered_at,
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
      remove_index :fts_targets, :registered_at
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

    remove_column :fts_targets, :registered_at
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

  def update_registered_at_using_last_modified_at
    type_names = ['Attachment', 'Change', 'Changeset', 'CustomValue', 'Document', 'Journal', 'News']

    FtsTarget.where(source_type_id: FtsType.where(name: type_names).select(:id))
             .update_all(registered_at: FtsTarget.arel_table[:last_modified_at])
  end

  def update_registered_at_using_created_on
    types = [Issue, Message, Project, WikiPage]
    types.each do |type|
      subquery_for_created_on = type.where(type.arel_table[:id].eq(FtsTarget.arel_table[:source_id]))
                                    .select(:created_on)
                                    .to_sql
      FtsTarget.where(source_type_id: FtsType.where(name: type.name.demodulize).select(:id))
               .update_all(registered_at: Arel.sql("(#{subquery_for_created_on})"))
    end
  end
end
