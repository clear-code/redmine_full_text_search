module FullTextSearch
  class Mapper
    class << self
      def attach(redmine_class)
        mapper_class = self
        redmine_class.class_eval do
          after_save mapper_class
          after_destroy mapper_class
        end
      end

      def after_save(record)
        mapper = redmine_mapper(record)
        mapper.upsert_searcher_record
      end

      def after_destroy(record)
        mapper = redmine_mapper(record)
        mapper.destroy_searcher_record
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
