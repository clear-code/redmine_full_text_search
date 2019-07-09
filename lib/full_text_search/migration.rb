module FullTextSearch
  module Migration
    if Redmine::Database.postgresql?
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
