module FullTextSearch
  class Mapper
    class << self
      def attach(redmine_class)
        mapper_class = self
        redmine_class.class_eval do
          after_commit mapper_class, on: [:create, :update]
          after_destroy mapper_class
          define_method(:to_searcher_record) do
            mapper_class.redmine_mapper(self).find_searcher_record
          end
        end
      end

      def after_commit(record)
        begin
          mapper = redmine_mapper(record)
          mapper.upsert_searcher_record
        rescue => error
          Rails.logger.error do
            message = "[full-text-search] Failed to upsert searcher record: "
            message << "#{error.class}: #{error.message}\n"
            message << error.backtrace.join("\n")
            message
          end
        end
      end

      def after_destroy(record)
        mapper = redmine_mapper(record)
        mapper.destroy_searcher_record
      end

      def redmine_class
        FullTextSearch.resolver.resolve(self)
      end

      def not_mapped_redmine_records
        redmine_mapper_class.not_mapped(redmine_class)
      end

      def orphan_searcher_records
        searcher_mapper_class.orphan(redmine_class)
      end

      def outdated_searcher_records
        searcher_mapper_class.outdated(redmine_class)
      end

      def redmine_mapper(record)
        redmine_mapper_class.new(self, record)
      end

      def searcher_mapper(record)
        searcher_mapper_class.new(self, record)
      end
    end
  end

  class RedmineMapper
    class << self
      def not_mapped(redmine_class)
        searcher_records =
          SearcherRecord
            .where(original_type: redmine_class.name)
            .select(:original_id)
        redmine_class
          .where.not(id: searcher_records)
          .order(id: :asc)
      end
    end

    def initialize(mapper, record)
      @mapper = mapper
      @record = record
    end

    def find_searcher_record
      SearcherRecord.find_or_initialize_by(searcher_record_keys)
    end

    def destroy_searcher_record
      SearcherRecord.where(searcher_record_keys).destroy_all
    end

    private
    def searcher_record_keys
      {
        original_id: @record.id,
        original_type: @record.class.name,
      }
    end
  end

  class SearcherMapper
    include Rails.application.routes.url_helpers
    include Redmine::I18n

    class << self
      def orphan(redmine_class)
        SearcherRecord
          .where(original_type: redmine_class.name)
          .joins(<<-SQL)
LEFT OUTER JOIN #{redmine_class.table_name}
  ON #{redmine_class.table_name}.id =
     #{SearcherRecord.table_name}.original_id
          SQL
          .where(redmine_class.table_name => {id: nil})
      end

      def outdated(redmine_class)
        unless redmine_class.column_names.include?("updated_on")
          return SearcherRecord.none
        end

        SearcherRecord
          .where(original_type: redmine_class.name)
          .joins(<<-SQL)
JOIN #{redmine_class.table_name}
  ON #{redmine_class.table_name}.id =
     #{SearcherRecord.table_name}.original_id
          SQL
          .where(<<-SQL)
#{SearcherRecord.table_name}.original_updated_on <
#{redmine_class.table_name}.updated_on
          SQL
      end
    end

    def initialize(mapper, record)
      @mapper = mapper
      @record = record
    end

    def redmine_record
      @redmine_record ||=
        FullTextSearch.resolver.resolve(@mapper).find(@record.original_id)
    end

    def redmine_mapper
      @mapper.redmine_mapper(redmine_record)
    end

    def type
      @record.original_type.underscore.dasherize
    end

    def title
      "#{title_prefix}#{@record.title}#{title_suffix}"
    end

    def description
      @record.description
    end

    def url
      {
        controller: "welcome",
      }
    end

    def title_prefix
      ""
    end

    def title_suffix
      ""
    end
  end
end
