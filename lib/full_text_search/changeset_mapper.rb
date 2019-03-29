module FullTextSearch
  class ChangesetMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineChangesetMapper
      end

      def searcher_mapper_class
        SearcherChangesetMapper
      end
    end
  end
  resolver.register(Changeset, ChangesetMapper)

  class RedmineChangesetMapper < RedmineMapper
    def upsert_searcher_record(options={})
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.repository.project_id
      searcher_record.project_name = @record.repository.project.name
      searcher_record.comments = @record.comments
      searcher_record.short_comments = @record.short_comments&.strip
      searcher_record.long_comments = @record.long_comments&.strip
      searcher_record.original_created_on = @record.committed_on
      searcher_record.save!
    end
  end

  class SearcherChangesetMapper < SearcherMapper
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

    def title
      if @record.short_comments.present?
        "#{title_prefix}#{@record.short_comments}"
      else
        title_prefix.chomp(": ")
      end
    end

    def description
      @record.long_comments.presence || @record.comments
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
