module FullTextSearch
  class CustomValueMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineCustomValueMapper
      end

      def searcher_mapper_class
        SearcherCustomValueMapper
      end
    end
  end
  resolver.register(CustomValue, CustomValueMapper)

  class RedmineCustomValueMapper < RedmineMapper
    def upsert_searcher_record(options={})
      searcher_record = find_searcher_record

      unless @record.custom_field.searchable
        searcher_record.destroy! if searcher_record.persisted?
        return
      end

      customized = @record.customized
      unless customized
        searcher_record.destroy! if searcher_record.persisted?
        return
      end

      # searchable CustomValue belongs to issue or project
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.value = @record.value
      searcher_record.custom_field_id = @record.custom_field_id
      case @record.customized_type
      when "Project"
        searcher_record.project_id = customized.id
        searcher_record.project_name = customized.name
      when "Issue"
        searcher_record.project_id = customized.project_id
        searcher_record.project_name = customized.project.name
        searcher_record.issue_id = customized.id
        # How to reflect new visibility when issue is changed to
        # private after custom value is created?
        searcher_record.is_private = customized.is_private
      else
        searcher_record.destroy! if searcher_record.persisted?
        return
      end
      searcher_record.save!
    end
  end

  class SearcherCustomValueMapper < SearcherMapper
    def type
      redmine_record.customized.event_type
    end

    def title
      redmine_record.customized.event_title
    end

    def description
      redmine_record.customized.event_description
    end

    def url
      redmine_record.customized.event_url
    end

    def id
      redmine_record.customized_id
    end

    def datetime
      redmine_record.customized.event_datetime
    end
  end
end
