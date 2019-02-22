module FullTextSearch
  class ProjectMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineProjectMapper
      end

      def searcher_mapper_class
        SearcherProjectMapper
      end
    end
  end
  resolver.register(Project, ProjectMapper)

  class RedmineProjectMapper < RedmineMapper
    def upsert_searcher_record
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.id
      searcher_record.project_name = @record.name
      searcher_record.name = @record.name
      searcher_record.description = @record.description
      searcher_record.identifier = @record.identifier
      searcher_record.status = @record.status
      searcher_record.original_created_on = @record.created_on
      searcher_record.original_updated_on = @record.updated_on
      searcher_record.save!
    end
  end

  class SearcherProjectMapper < SearcherMapper
    def title_prefix
      "#{l(:label_project)}: "
    end

    def title
      "#{title_prefix}#{@record.name}"
    end

    def url
      {
        controller: "projects",
        action: "show",
        id: @record.original_id
      }
    end
  end
end
