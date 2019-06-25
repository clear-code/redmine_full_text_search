module FullTextSearch
  class ChangesetMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineChangesetMapper
      end

      def fts_mapper_class
        FtsChangesetMapper
      end
    end
  end
  resolver.register(Changeset, ChangesetMapper)

  class RedmineChangesetMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class.joins(repository: :project)
      end
    end

    def upsert_fts_target(options={})
      repository = @record.repository
      fts_target = find_fts_target
      if repository.nil?
        fts_target.destroy! if fts_target.persisted?
        return
      end
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = repository.project_id
      if @record.user
        fts_target.tag_ids = [Tag.user(@record.user.id).id]
      end
      fts_target.title = @record.short_comments&.strip
      fts_target.content = @record.long_comments&.strip
      fts_target.last_modified_at = @record.committed_on
      fts_target.save!
    end
  end

  class FtsChangesetMapper < FtsMapper
    def title_prefix
      changeset = redmine_record
      repository = changeset.repository
      if repository and repository.identifier.present?
        repository = " (#{repository.identifier})"
      else
        repository = ""
      end
      "#{l(:label_revision)} #{changeset.format_identifier}#{repository}: "
    end

    def url
      changeset = redmine_record
      {
        controller: "repositories",
        action: "revision",
        id: @record.project_id,
        repository_id: changeset.repository.identifier_param,
        rev: changeset.identifier,
      }
    end
  end
end
