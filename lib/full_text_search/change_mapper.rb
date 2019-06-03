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
      def not_mapped(redmine_class)
        fts_targets =
          Target
            .where(source_type_id: Type[redmine_class].id)
            .select(:source_id)
        targets = redmine_class.where.not(id: fts_targets)
        last_source_id =
          fts_targets
            .order(source_id: :desc)
            .limit(1)
            .pluck(:source_id)
            .first
        if last_source_id
          targets = targets.where(id: (last_source_id + 1)..Float::INFINITY)
        end
        targets.order(id: :asc)
      end
    end

    def upsert_fts_target(options={})
      case @record.action
      when "A", "M"
        changeset = @record.changeset
        repository = changeset.repository
        identifier = changeset.identifier
        entry = repository.entry(@record.path, identifier)
        return unless entry.is_file?
        fts_target = find_fts_target
        fts_target.source_id = @record.id
        fts_target.source_type_id = Type[@record.class].id
        fts_target.container_id = repository.id
        fts_target.container_type_id = Type.repository.id
        fts_target.project_id = repository.project_id
        extractor = TextExtractor.new
        repository.scm.cat_io(entry.path, identifier) do |input|
          begin
            # TODO: Check property for content type
            fts_target.content = extractor.extract(Pathname(entry.path),
                                                   input,
                                                   nil)
          rescue => error
            Rails.logger.error do
              "[full-text-search][text-extract][change] " +
                "Failed to extract text: #{error.class}: #{error.message}\n" +
                error.backtrace.join("\n")
            end
          end
        end
        fts_target.last_modified_at = changeset.committed_on
        fts_target.tag_ids = extract_tag_ids_from_path(fts_target.title)
        Target.where(source_type_id: fts_target.source_type_id,
                     container_id: fts_target.container_id,
                     container_type_id: fts_target.container_type_id,
                     title: fts_target.title).destroy_all
        fts_target.save!
      when "D"
        destroy_fts_target
      end
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
