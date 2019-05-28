module FullTextSearch
  class ChangeMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineChangeMapper
      end

      def searcher_mapper_class
        SearcherChangeMapper
      end
    end
  end
  resolver.register(Change, ChangeMapper)

  class RedmineChangeMapper < RedmineMapper
    class << self
      def not_mapped(redmine_class)
        searcher_records =
          SearcherRecord
            .where(original_type: redmine_class.name)
            .select(:original_id)
        targets = redmine_class.where.not(id: searcher_records)
        last_original_id =
          searcher_records
            .order(original_id: :desc)
            .limit(1)
            .pluck(:original_id)
            .first
        if last_original_id
          targets = targets.where(id: (last_original_id + 1)..Float::INFINITY)
        end
        targets.order(id: :asc)
      end
    end

    def upsert_searcher_record(options={})
      case @record.action
      when "A", "M"
        changeset = @record.changeset
        repository = changeset.repository
        identifier = changeset.identifier
        entry = repository.entry(@record.path, identifier)
        return unless entry.is_file?
        searcher_record = find_searcher_record
        searcher_record.original_id = @record.id
        searcher_record.original_type = @record.class.name
        searcher_record.container_id = repository.id
        searcher_record.container_type = "Repository"
        searcher_record.project_id = repository.project_id
        searcher_record.project_name = repository.project.name
        searcher_record.identifier = identifier
        extractor = TextExtractor.new
        repository.scm.cat_io(entry.path, identifier) do |input|
          begin
            # TODO: Check property for content type
            searcher_record.content = extractor.extract(Pathname(entry.path),
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
        searcher_record.original_created_on = changeset.committed_on
        searcher_record.original_updated_on = changeset.committed_on
        SearcherRecord.where(original_type: searcher_record.original_type,
                             container_id: searcher_record.container_id,
                             container_type: searcher_record.container_type,
                             filename: searcher_record.filename).destroy_all
        searcher_record.save!
      when "D"
        destroy_searcher_record
      end
    end

    private
    def searcher_record_keys
      {
        original_id: @record.id,
        original_type: @record.class.name,
        filename: @record.path,
      }
    end
  end

  class SearcherChangeMapper < SearcherMapper
    def title_prefix
      change = redmine_record
      "#{change.changeset.repository.identifier}:"
    end

    def title_suffix
      "@#{@record.identifier}"
    end

    def type
      "file"
    end

    def url
      change = redmine_record
      {
        controller: "repositories",
        action: "entry",
        id: @record.project_id,
        repository_id: change.changeset.repository.id,
        rev: @record.identifier,
        path: @record.filename,
      }
    end
  end
end
