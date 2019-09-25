require "full_text_search/migration"

class CreateFtsTargets < ActiveRecord::Migration[5.2]
  def comparable_version(version)
    version.split(".").collect {|component| Integer(component, 10)}
  end

  def change
    if Redmine::Database.mysql?
      mroonga_version = connection.select_rows(<<-SQL)[0][1]
SHOW VARIABLES LIKE 'mroonga_version';
      SQL
      required_mroonga_version = "9.03"
      if (comparable_version(mroonga_version) <=>
          comparable_version(required_mroonga_version)) < 0
        message = "Mroonga #{required_mroonga_version} or later is required: " +
                  mroonga_version
        raise message
      end
      options = "ENGINE=Mroonga"
    else
      options = nil
    end
    create_table :fts_targets, options: options do |t|
      t.integer :source_id, null: false
      t.integer :source_type_id, null: false
      t.integer :project_id, null: false
      t.integer :container_id
      t.integer :container_type_id
      t.integer :custom_field_id
      t.boolean :is_private
      t.timestamp :last_modified_at
      t.text :title
      if Redmine::Database.mysql?
        t.text :content,
               limit: 16.megabytes,
               comment: "FLAGS 'COLUMN_SCALAR|COMPRESS_ZSTD'"
      else
        t.text :content
      end
      if Redmine::Database.mysql?
        t.text :tag_ids,
               comment: "FLAGS 'COLUMN_VECTOR', GROONGA_TYPE 'Int32'"
      else
        t.integer :tag_ids, array: true
      end
      t.index [:source_id, :source_type_id], unique: true
      if Redmine::Database.mysql?
        t.index :project_id
        t.index :container_id
        t.index :container_type_id
        t.index :custom_field_id
        t.index :is_private
        t.index :last_modified_at
        t.index :title,
                type: "fulltext",
                comment: "NORMALIZER 'NormalizerNFKC121'"
        t.index :content,
                type: "fulltext",
                comment: "NORMALIZER 'NormalizerNFKC121', INDEX_FLAGS 'WITH_POSITION|INDEX_LARGE'"
        t.index :tag_ids,
                type: "fulltext",
                comment: "LEXICON 'fts_tags', INDEX_FLAGS ''"
      else
        t.index [:id,
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
    end
  end
end
