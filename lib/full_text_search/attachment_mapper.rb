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

      searcher_record = find_searcher_record
      return unless searcher_record.persisted?

      context = {
        searcher_record: searcher_record,
        content: nil,
        path: @record.diskfile,
        content_type: @record.content_type,
        max_size: Setting.plugin_full_text_search.attachment_max_text_size,
      }
      resolve_context(context)
      Rails.logger.debug do
        format_log_message("Extracting...", context)
      end
      begin
        extractor = TextExtractor.new(context[:path],
                                      context[:content_type],
                                      context[:max_size])
        context[:content] = extractor.extract
      rescue => error
        Rails.logger.error do
          format_log_message("Failed to extract text",
                             context,
                             error)
        end
        return
      rescue NoMemoryError => error
        Rails.logger.error do
          format_log_message("Failed to extract text by no memory",
                             context,
                             error)
        end
        return
      end
      Rails.logger.debug do
        format_log_message("Extracted", context)
      end

      content = context[:content]
      if content.encoding == Encoding::ASCII_8BIT
        content.force_encoding(Encoding::UTF_8)
      else
        content.encode!(Encoding::UTF_8,
                        invalid: :replace,
                        undef: :replace,
                        replace: "")
      end
      original_size = content.bytesize
      if original_size > context[:max_size]
        content = content.byteslice(0, context[:max_size])
      end
      content.scrub!("")
      if original_size > context[:max_size]
        Rails.logger.info do
          format_log_message("Truncated extracted text: " +
                             "#{original_size} -> #{content.bytesize}",
                             context)
        end
      end
      searcher_record.content = content
      searcher_record.save!
    end

    private
    def resolve_context(context)
      case context[:content_type]
      when "application/x-tar"
        case File.extname(context[:path]).downcase
        when ".gz"
          context[:content_type] = "application/gzip"
        when ".bz2"
          context[:content_type] = "application/x-bzip2"
        end
      end
    end

    def format_log_message(message, context, error=nil)
      formatted_message = "[full-text-search][text-extract] #{message}: "
      formatted_message << "SearcherRecord: #{context[:searcher_record].id}: "
      formatted_message << "Attachment: #{@record.id}: "
      formatted_message << "path: <#{context[:path]}>: "
      formatted_message << "content-type: <#{context[:content_type]}>"
      if error
        formatted_message << ": #{error.class}: #{error.message}\n"
        formatted_message << error.backtrace.join("\n")
      end
      formatted_message
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
