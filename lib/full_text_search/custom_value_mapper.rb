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
      return unless @record.custom_field.searchable

      searcher_record = find_searcher_record
      # searchable CustomValue belongs to issue or project
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.value = @record.value
      searcher_record.custom_field_id = @record.custom_field_id
      case @record.customized_type
      when "Project"
        searcher_record.project_id = @record.customized.id
        searcher_record.project_name = @record.customized.name
      when "Issue"
        searcher_record.project_id = @record.customized.project_id
        searcher_record.project_name = @record.customized.project.name
        searcher_record.status_id = @record.customized.status_id
        searcher_record.is_private = @record.customized.is_private
      else
        # Not in use for now...
        searcher_record.project_id = @record.customized.project_id
        searcher_record.project_name = @record.customized.project.name
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
  end
end
