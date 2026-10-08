module FullTextSearch
  module Migration
    if Redmine::Database.postgresql?
      # TODO: Send a patch for WITH support to Active Record.

      module IndexDefinitionWithSupport
        attr_accessor :with
      end
      ::ActiveRecord::ConnectionAdapters::IndexDefinition.prepend(IndexDefinitionWithSupport)

      module SchemaCreationWithSupport
        private
        def visit_CreateIndexDefinition(o)
          sql = super
          with = o.index.with
          return sql unless with

          with_sql = " WITH (#{with})"
          where = o.index.where
          if where
            sql.sub(" WHERE #{where}", "#{with_sql} WHERE #{where}")
          else
            sql << with_sql
          end
        end
      end
      ::ActiveRecord::ConnectionAdapters::SchemaCreation.prepend(SchemaCreationWithSupport)

      module PostgreSQLAdapterWithSupport
        def add_index_options(table_name, column_name, with: nil, **options)
          result = super(table_name, column_name, **options)
          result[0].with = with
          result
        end
      end
      ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgreSQLAdapterWithSupport)
    end
  end
end
