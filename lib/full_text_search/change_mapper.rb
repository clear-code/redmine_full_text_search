module FullTextSearch
  class ChangeMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineChangeMapper
      end

      def fts_mapper_class
        FtsChangeMapper
      end
    end
  end
  resolver.register(Change, ChangeMapper)

  class RedmineChangeMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class.joins(changeset: {repository: :project})
      end

      def not_mapped(redmine_class, options={})
        source_ids =
          redmine_class
            .joins(changeset: [:repository])
            .group("repositories.id, changes.path")
            .select("MAX(changes.id) as id")
        super.where(id: source_ids)
      end
    end

    def upsert_fts_target(options={})
      case @record.action
      when "A", "M"
        changeset = @record.changeset
        repository = changeset.repository
        return if repository.nil?
        identifier = changeset.identifier
        relative_path = repository.relative_path(@record.path)
        entry = repository.entry(relative_path, identifier)
        return if entry.nil?
        return unless entry.is_file?
        fts_target = find_fts_target
        fts_target.source_id = @record.id
        fts_target.source_type_id = Type[@record.class].id
        fts_target.container_id = repository.id
        fts_target.container_type_id = Type.repository.id
        fts_target.project_id = repository.project_id
        fts_target.last_modified_at = changeset.committed_on
        fts_target.tag_ids = extract_tag_ids_from_path(fts_target.title)
        prepare_text_extraction(fts_target)
        Target.where(source_type_id: fts_target.source_type_id,
                     container_id: fts_target.container_id,
                     container_type_id: fts_target.container_type_id,
                     title: fts_target.title).destroy_all
        fts_target.save!
        extract_content(fts_target, options)
      when "D"
        destroy_fts_target
      end
    end

    def extract_text
      changeset = @record.changeset
      repository = changeset.repository
      return if repository.nil?
      identifier = changeset.identifier
      relative_path = repository.relative_path(@record.path)
      entry = repository.entry(relative_path, identifier)
      return if entry.nil?
      return unless entry.is_file?

      fts_target = find_fts_target
      return unless fts_target.persisted?

      # TODO: Check property for content type
      content_type = nil
      metadata = [
        ["path", @record.path],
        # ["content-type", content_type],
      ]
      content = run_text_extractor(fts_target, metadata) do |extractor|
        repository.scm.cat_io(@record.path, identifier) do |input|
          extractor.extract(Pathname(@record.path),
                            input,
                            content_type)
        end
      end
      set_extracted_content(fts_target, content)
      fts_target.save!
    end

    private
    def fts_target_keys
      {
        source_id: @record.id,
        source_type_id: Type[@record.class].id,
        title: @record.path,
      }
    end
  end

  class FtsChangeMapper < FtsMapper
    def title_prefix
      change = redmine_record
      repository = change.changeset.repository
      if repository.identifier.blank?
        ""
      else
        "#{repository.identifier}:"
      end
    end

    def title_suffix
      change = redmine_record
      "@#{change.changeset.identifier}"
    end

    def type
      "file"
    end

    def url
      change = redmine_record
      changeset = change.changeset
      {
        controller: "repositories",
        action: "entry",
        id: @record.project_id,
        repository_id: changeset.repository.identifier_param,
        rev: changeset.identifier,
        path: change.path.gsub(/\A\//, ""),
      }
    end
  end
end
