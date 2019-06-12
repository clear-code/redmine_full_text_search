migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class CreateFtsTargets < migration
  if Redmine::Database.mysql? and Rails::VERSION::MAJOR == 4
    ActiveRecord::ConnectionAdapters::ColumnDefinition.attr_accessor :comment

    module TableDefinitionCommentable
      def new_column_definition(name, type, options)
        definition = super
        definition.comment = options[:comment]
        definition
      end
    end
    ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionCommentable)

    module Mysql2AdapterCommentable
      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns, index_options, _, _, comment = add_index_options(table_name, column_name, options)
        sql = "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{index_columns})#{index_options}"
        sql << " COMMENT '#{comment.gsub(/'/, "''")}'" if comment
        execute sql
      end

      def add_index_options(table_name, column_name, comment: nil, **options)
        super(table_name, column_name, **options) + [comment]
      end
    end
    ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(Mysql2AdapterCommentable)

    module MysqlSchemaCreationCommentable
      def add_column_options!(sql, options)
        sql = super(sql, options)
        comment = options[:comment]
        sql << " COMMENT '#{comment.gsub(/'/, "''")}'" if comment
        sql
      end

      def column_options(o)
        options = super
        options[:comment] = o.comment
        options
      end

      def index_in_create(table_name, column_name, options)
        index_name, index_type, index_columns, index_options, index_algorithm, index_using, comment = @conn.add_index_options(table_name, column_name, options)
        sql = "#{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns})#{index_options} #{index_algorithm}"
        sql << " COMMENT '#{comment.gsub(/'/, "''")}'" if comment
        sql
      end
    end
    ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::SchemaCreation.prepend(MysqlSchemaCreationCommentable)
  end

  def change
    if Redmine::Database.mysql?
      # TODO: Check Mroonga 9.03 or later
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
        t.index :title, type: "fulltext"
        t.index :content,
                type: "fulltext",
                comment: "INDEX_FLAGS 'WITH_POSITION|INDEX_LARGE'"
        t.index :tag_ids,
                type: "fulltext",
                comment: "LEXICON 'fts_tags', INDEX_FLAGS ''"
      else
        t.index [:source_id,
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
                name: "fts_targets_index_pgroonga"
      end
    end
  end
end
