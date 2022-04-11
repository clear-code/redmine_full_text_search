module FullTextSearch
  module Migration
    if Redmine::Database.postgresql?
      # TODO: Send a patch for WITH support to Active Record.

      # For Redmine 4.2 or earlier
      if ::ActiveRecord::VERSION::MAJOR <= 5
        module PostgreSQLAdapterWithSupport
          def add_index_options(table_name, column_name, with: nil, **options)
            result = super(table_name, column_name, **options)
            result[3] += " WITH (#{with})" if with
            result
          end
        end
        ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgreSQLAdapterWithSupport)
      else
        module IndexDefinitionWithSupport
          attr_accessor :with
        end
        ::ActiveRecord::ConnectionAdapters::IndexDefinition.prepend(IndexDefinitionWithSupport)

        module SchemaCreationWithSupport
          private
          def visit_CreateIndexDefinition(o)
            sql = super
            with = o.index.with
            sql << " WITH (#{with})" if with
            sql
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
end
