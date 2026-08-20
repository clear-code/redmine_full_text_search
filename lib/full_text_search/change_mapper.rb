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
            .joins(:changeset)
            .group("changesets.repository_id, changes.path")
            .select("MAX(changes.id) as id")
        super.where(action: ["A", "M", "R"],
                    id: source_ids)
      end
    end

    def upsert_fts_target(options={})
      changeset = @record.changeset
      return if changeset.nil?
      repository = changeset.repository
      return if repository.nil?

      case @record.action
      when "A", "M", "R"
        entry = RepositoryEntry.new(repository,
                                    @record.path,
                                    changeset.identifier)
        return unless entry.file?
        return if find_newer_fts_targets.exists?

        fts_target = nil
        if @record.from_path
          from_change =
            Change
              .joins(changeset: :repository)
              .find_by(repositories: {id: repository.id},
                       changesets: {revision: @record.from_revision},
                       path: @record.from_path)
          if from_change
            fts_target = Target.find_by(source_id: from_change.id,
                                        source_type_id: Type[from_change].id,
                                        title: from_change)
          end
        end
        fts_target ||= find_old_fts_targets.first
        fts_target ||= find_fts_target
        fts_target.title = target_title
        fts_target.source_id = @record.id
        fts_target.source_type_id = Type[@record.class].id
        fts_target.container_id = repository.id
        fts_target.container_type_id = Type.repository.id
        fts_target.project_id = repository.project_id
        fts_target.last_modified_at = changeset.committed_on
        fts_target.registered_at = changeset.committed_on
        fts_target.tag_ids = extract_tag_ids_from_path(@record.path)
        if fts_target.changed?
          prepare_text_extraction(fts_target)
          fts_target.save!
          extract_content(fts_target, options)
        end
      when "D"
        # For Subversion:
        # When moving a directory, Changes are inserted in the form `D from_dir`, `A to_dir`.
        # At that time, since we reuse the file level fts_target data from before the move,
        # we do not delete it.
        return if directory_move_destination?

        # In the case of `D`, `entry.{file?,directory?}` is `nil` and cannot be used.
        # Therefore, we use `descendants: true`, which can find targets in both file
        # and directory.
        find_old_fts_targets(descendants: true).destroy_all
      end
    end

    def extract_text
      changeset = @record.changeset
      repository = changeset.repository
      return if repository.nil?
      entry = RepositoryEntry.new(repository,
                                  @record.path,
                                  changeset.identifier)
      return unless entry.file?

      fts_target = find_fts_target
      return unless fts_target.persisted?

      # TODO: Check property for content type
      content_type = nil
      metadata = [
        ["path", @record.path],
        # ["content-type", content_type],
      ]
      content = run_text_extractor(fts_target, metadata) do |extractor|
        entry.cat do |input|
          extractor.extract(Pathname(@record.path),
                            input,
                            content_type)
        end
      end
      set_extracted_content(fts_target, content)
      fts_target.save!
    end

    private
    def target_title
      "#{@record.path}@#{@record.changeset.identifier}"
    end

    def fts_target_keys
      {
        source_id: @record.id,
        source_type_id: Type[@record].id,
        title: target_title,
      }
    end

    def directory_move_destination?
      change = Change
        .where(changeset_id: @record.changeset_id,
               action: ["A", "R"],
               from_path: @record.path)
        .first
      return false unless change
      entry = RepositoryEntry.new(change.changeset.repository,
                                  change.path,
                                  change.changeset.identifier)
      entry.directory?
    end

    def find_fts_targets(path: nil, descendants: false)
      escaped_path = Target.sanitize_sql_like(path || @record.path)
      # Exclude `@%@%` so that `file.txt@<revision>` doesn't match `file.txt@2026`
      # when both `file.txt` and `file.txt@2026` exist.
      condition = "title LIKE ? AND title NOT LIKE ?"
      values = ["#{escaped_path}@%", "#{escaped_path}@%@%"]
      if descendants
        # Also match descendants, to support cases where `path` is a directory.
        condition = "(#{condition}) OR title LIKE ?"
        values << "#{escaped_path}/%"
      end

      Target
        .joins(<<-JOIN)
  JOIN changes
    ON source_type_id = #{Type.change.id} AND
       source_id = changes.id
  JOIN changesets
    ON changes.changeset_id = changesets.id
  JOIN repositories
    ON changesets.repository_id = repositories.id
        JOIN
        .where(repositories: {id: @record.changeset.repository.id})
        .where(condition, *values)
    end

    def find_old_fts_targets(path: nil, descendants: false)
      find_fts_targets(path: path, descendants: descendants)
        .where(changesets: {id: -Float::INFINITY...@record.changeset_id})
    end

    def find_newer_fts_targets
      find_fts_targets
        .where(changesets: {id: (@record.changeset_id + 1)..Float::INFINITY})
    end
  end

  class FtsChangeMapper < FtsMapper
    class PathResolver
      include ApplicationHelper

      def initialize(repository, path)
        @repository = repository
        @path = path
      end

      def resolve
        to_path_param(@repository.relative_path(@path))
      end
    end

    def title_prefix
      change = redmine_record
      repository = change.changeset.repository
      if repository.identifier.blank?
        ""
      else
        "#{repository.identifier}:"
      end
    end

    def type
      "file"
    end

    def url
      repository = redmine_record.changeset.repository
      path, separator, revision = @record.title.rpartition("@")
      {
        controller: "repositories",
        action: "entry",
        id: @record.project_id,
        repository_id: repository.identifier_param,
        rev: revision,
        path: PathResolver.new(repository, path).resolve,
      }
    end
  end
end
