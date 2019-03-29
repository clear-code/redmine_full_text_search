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
            .where(original_type: original_type(redmine_class))
            .select(:original_id)
        redmine_class.where.not(original_id_column => searcher_records)
      end

      def original_id_column
        :id
      end

      def original_type(redmine_class)
        redmine_class.name
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
        original_id: @record.__send__(self.class.original_id_column),
        original_type: self.class.original_type(@record.class),
      }
    end
  end

  class SearcherMapper
    include Rails.application.routes.url_helpers
    include Redmine::I18n

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
      "#{title_prefix}#{@record.title}"
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
  end
end
