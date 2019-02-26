require "chupa-text"

module FullTextSearch
  class AttachmentMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineAttachmentMapper
      end

      def searcher_mapper_class
        SearcherAttachmentMapper
      end
    end
  end
  resolver.register(Attachment, AttachmentMapper)

  class RedmineAttachmentMapper < RedmineMapper
    def upsert_searcher_record
      # container is not specified when initial upload
      return if @record.container_type.nil?

      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.container_id = @record.container_id
      searcher_record.container_type = @record.container_type
      searcher_record.filename = @record.filename
      searcher_record.description = @record.description
      searcher_record.original_created_on = @record.created_on
      case @record.container_type
      when "Project"
        searcher_record.project_id = @record.container.id
        searcher_record.project_name = @record.container.name
      when "Message"
        searcher_record.project_id = @record.container.board.project_id
        searcher_record.project_name = @record.container.board.project.name
      when "WikiPage"
        wiki_page = @record.container
        searcher_record.project_id = wiki_page.wiki.project_id
        searcher_record.project_name = wiki_page.wiki.project.name
      when "Issue"
        issue = @record.container
        searcher_record.issue_id = issue.id
        searcher_record.project_id = issue.project_id
        searcher_record.project_name = issue.project.name
        searcher_record.status_id = issue.status_id
        searcher_record.is_private = issue.is_private
      else
        return unless @record.container.respond_to?(:project_id)
        searcher_record.project_id = @record.container.project_id
        searcher_record.project_name = @record.container.project.name
      end
      searcher_record.save!
      ExtractTextJob.perform_later(searcher_record.id)
    end

    def extract_text
      return unless @record.readable?

      extractor = TextExtractor.new(@record.diskfile,
                                    @record.content_type)
      text = extractor.extract
      return if text.nil?

      searcher_record = find_searcher_record
      searcher_record.content = text
      searcher_record.save!
    end
  end

  class SearcherAttachmentMapper < SearcherMapper
    def title
      @record.filename
    end

    def url
      {
        controller: "attachments",
        action: "show",
        id: @record.original_id,
        filename: @record.filename,
      }
    end
  end
end
