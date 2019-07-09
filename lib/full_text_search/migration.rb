module FullTextSearch
  module Migration
    if Redmine::Database.mysql?
      if Rails::VERSION::MAJOR == 4
        ::ActiveRecord::ConnectionAdapters::ColumnDefinition.attr_accessor :comment

        module TableDefinitionCommentable
          def new_column_definition(name, type, options)
            definition = super
            definition.comment = options[:comment]
            definition
          end
        end
        ::ActiveRecord::ConnectionAdapters::TableDefinition.prepend(TableDefinitionCommentable)

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
        ::ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(Mysql2AdapterCommentable)

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
        ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::SchemaCreation.prepend(MysqlSchemaCreationCommentable)
      end
    elsif Redmine::Database.postgresql?
      module PostgreSQLAdapterOptionable
        def add_index_options(table_name, column_name, with: nil, **options)
          result = super(table_name, column_name, **options)
          result[3] += " WITH (#{with})" if with
          result
        end
      end
      ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgreSQLAdapterOptionable)
    end
  end
end
