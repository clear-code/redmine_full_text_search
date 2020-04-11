module FullTextSearch
  class CustomValueMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineCustomValueMapper
      end

      def fts_mapper_class
        FtsCustomValueMapper
      end
    end
  end
  resolver.register(CustomValue, CustomValueMapper)

  class RedmineCustomValueMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class
          .joins(<<-JOIN)
LEFT OUTER JOIN issues
  ON customized_type = 'Issue' AND issues.id = customized_id
          JOIN
          .joins(<<-JOIN)
JOIN projects
  ON (customized_type = 'Project' AND projects.id = customized_id) OR
     (customized_type = 'Issue' AND projects.id = issues.project_id)
          JOIN
      end

      def not_mapped(redmine_class, options)
        super
          .joins(:custom_field)
          .where("custom_fields.searchable")
      end
    end

    def upsert_fts_target(options={})
      fts_target = find_fts_target

      unless @record.custom_field.searchable?
        fts_target.destroy! if fts_target.persisted?
        return
      end

      customized = @record.customized
      unless customized
        fts_target.destroy! if fts_target.persisted?
        return
      end

      # searchable CustomValue belongs to issue or project
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.content = @record.value
      fts_target.custom_field_id = @record.custom_field_id
      case @record.customized_type
      when "Issue"
        fts_target.project_id = customized.project_id
        fts_target.is_private = customized.is_private
      when "Project"
        fts_target.project_id = customized.id
      else
        fts_target.destroy! if fts_target.persisted?
        return
      end
      fts_target.container_id = customized.id
      fts_target.container_type_id = Type[customized].id
      # TODO: This may not be updated when issue or project is updated.
      fts_target.last_modified_at = customized.updated_on
      fts_target.save!
    end
  end

  class FtsCustomValueMapper < FtsMapper
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
  end
end
