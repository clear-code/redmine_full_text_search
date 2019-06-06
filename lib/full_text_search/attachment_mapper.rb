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
      when "Project"
        fts_target.project_id = @record.container_id
      when "Message"
        fts_target.project_id = @record.container.board.project_id
      when "WikiPage"
        wiki_page = @record.container
        fts_target.project_id = wiki_page.wiki.project_id
      when "Issue"
        issue = @record.container
        fts_target.project_id = issue.project_id
        fts_target.is_private = issue.is_private
        tag_ids << Tag.issue_status(issue.status_id).id
      else
        return unless @record.container.respond_to?(:project_id)
        fts_target.project_id = @record.container.project_id
      end
      fts_target.container_id = @record.container_id
      fts_target.container_type_id = Type[@record.container_type].id
      fts_target.tag_ids = tag_ids + extract_tag_ids_from_path(@record.filename)
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
        extractor.extract(path, nil, content_type)
      end
      contents = [
        @record.description.presence,
        content.presence,
      ]
      fts_target.content = contents.compact.join("\n")
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
