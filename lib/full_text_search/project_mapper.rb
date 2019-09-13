module FullTextSearch
  class ProjectMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineProjectMapper
      end

      def fts_mapper_class
        FtsProjectMapper
      end
    end
  end
  resolver.register(Project, ProjectMapper)

  class RedmineProjectMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class
      end
    end

    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.id
      fts_target.title = @record.identifier
      fts_target.content = "#{@record.name} #{@record.description}"
      fts_target.last_modified_at = @record.updated_on
      fts_target.save!
    end
  end

  class FtsProjectMapper < FtsMapper
    def title_prefix
      "#{l(:label_project)}: "
    end

    def title_content
      redmine_record.name
    end

    def url
      {
        controller: "projects",
        action: "show",
        id: @record.source_id
      }
    end
  end
end
