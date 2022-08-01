module FullTextSearch
  class AttachmentMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineAttachmentMapper
      end

      def fts_mapper_class
        FtsAttachmentMapper
      end
    end
  end
  resolver.register(Attachment, AttachmentMapper)

  class RedmineAttachmentMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class
          .joins(<<-JOIN)
LEFT OUTER JOIN documents
  ON container_type = 'Document' AND documents.id = container_id
          JOIN
          .joins(<<-JOIN)
LEFT OUTER JOIN issues
  ON container_type = 'Issue' AND issues.id = container_id
          JOIN
          .joins(<<-JOIN)
LEFT OUTER JOIN messages
  ON container_type = 'Message' AND messages.id = container_id
          JOIN
          .joins(<<-JOIN)
LEFT OUTER JOIN boards
  ON container_type = 'Message' AND boards.id = messages.board_id
          JOIN
          .joins(<<-JOIN)
LEFT OUTER JOIN wiki_pages
  ON container_type = 'WikiPage' AND wiki_pages.id = container_id
          JOIN
          .joins(<<-JOIN)
LEFT OUTER JOIN wikis
  ON container_type = 'WikiPage' AND wikis.id = wiki_pages.wiki_id
          JOIN
          .joins(<<-JOIN)
JOIN projects
  ON (container_type = 'Document' AND projects.id = documents.project_id) OR
     (container_type = 'Issue' AND projects.id = issues.project_id) OR
     (container_type = 'Message' AND projects.id = boards.project_id) OR
     (container_type = 'Project' AND projects.id = container_id) OR
     (container_type = 'WikiPage' AND projects.id = wikis.project_id)
          JOIN
      end
    end

    def upsert_fts_target(options={})
      # container is not specified when initial upload
      return if @record.container_type.nil?

      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.title = @record.filename
      fts_target.content = @record.description
      fts_target.last_modified_at = @record.created_on
      tag_ids = []
      case @record.container_type
      when "Issue"
        issue = @record.container
        return if issue.nil?
        fts_target.project_id = issue.project_id
        fts_target.is_private = issue.is_private
        tag_ids << Tag.issue_status(issue.status_id).id
      when "Message"
        fts_target.project_id = @record.container.board.project_id
      when "Project"
        fts_target.project_id = @record.container_id
      when "WikiPage"
        wiki_page = @record.container
        fts_target.project_id = wiki_page.wiki.project_id
      else
        return unless @record.container.respond_to?(:project_id)
        fts_target.project_id = @record.container.project_id
      end
      fts_target.container_id = @record.container_id
      fts_target.container_type_id = Type[@record.container_type].id
      tag_ids.concat(extract_tag_ids_from_path(@record.filename))
      fts_target.tag_ids = tag_ids
      prepare_text_extraction(fts_target)
      fts_target.save!
      extract_content(fts_target, options)
    end

    def extract_text
      return unless @record.readable?

      fts_target = find_fts_target
      return unless fts_target.persisted?

      path = @record.diskfile
      content_type = resolve_content_type(path, @record.content_type)
      metadata = [
        ["path", path],
        ["content-type", content_type],
      ]
      content = run_text_extractor(fts_target, metadata) do |extractor|
        if @record.respond_to?(:raw_data)
          input = StringIO.new(@record.raw_data)
        else
          input = nil
        end
        extractor.extract(path, input, content_type)
      end
      set_extracted_content(fts_target,
                            content,
                            [@record.description.presence])
      fts_target.save!
    end

    private
    def resolve_content_type(path, content_type)
      case content_type
      when "application/x-tar"
        case File.extname(path).downcase
        when ".gz"
          "application/gzip"
        when ".bz2"
          "application/x-bzip2"
        else
          content_type
        end
      else
        content_type
      end
    end
  end

  class FtsAttachmentMapper < FtsMapper
    def title
      @record.filename
    end

    def url
      {
        controller: "attachments",
        action: "show",
        id: @record.source_id,
        filename: @record.title,
      }
    end
  end
end
