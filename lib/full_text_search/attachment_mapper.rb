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
      case options[:extract_text]
      when :immediate
        extract_text
      when :none
        # Do nothing
      else
        ExtractTextJob.perform_later(fts_target.id)
      end
    end

    def extract_text
      return unless @record.readable?

      fts_target = find_fts_target
      return unless fts_target.persisted?

      before_memory_usage = memory_usage
      start_time = Time.now
      context = {
        fts_target: fts_target,
        content: nil,
        path: @record.diskfile,
        content_type: @record.content_type,
        memory_usage: before_memory_usage,
      }
      resolve_context(context)
      Rails.logger.info do
        format_log_message("Extracting...", context)
      end
      begin
        extractor = TextExtractor.new
        context[:content] = extractor.extract(context[:path],
                                              nil,
                                              context[:content_type])
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
      context[:elapsed_time] = Time.now - start_time
      after_memory_usage = memory_usage
      context[:memory_usage_diff] = after_memory_usage - before_memory_usage
      context[:memory_usage] = after_memory_usage
      Rails.logger.info do
        format_log_message("Extracted", context)
      end
      contents = [
        @record.description.presence,
        context[:content].presence,
      ]
      fts_target.content = contents.compact.join("\n")
      fts_target.save!
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

    def memory_usage
      status_path = "/proc/self/status"
      if File.exist?(status_path)
        File.open(status_path) do |status|
          status.each_line do |line|
            case line
            when /\AVmRSS:\s+(\d+) kB/
              return Integer($1, 10) * 1024
            end
          end
        end
      end
      0
    end

    def format_log_message(message, context, error=nil)
      formatted_message = "[full-text-search][text-extract] #{message}: "
      formatted_message << "FullTextSearch::Target: #{context[:fts_target].id}: "
      formatted_message << "Attachment: #{@record.id}: "
      formatted_message << "path: <#{context[:path]}>: "
      formatted_message << "content-type: <#{context[:content_type]}>"
      elapsed_time = context[:elapsed_time]
      if elapsed_time
        if elapsed_time < 1
          formatted_elapsed_time = "%.2fms" % (elapsed_time * 1000)
        elsif elapsed_time < 60
          formatted_elapsed_time = "%.2fs" % elapsed_time
        elsif elapsed_time < (60 * 60)
          formatted_elapsed_time = "%.2fm" % (elapsed_time / 60)
        else
          formatted_elapsed_time = "%.2fh" % (elapsed_time / 60 / 60)
        end
        formatted_message << ": elapsed time: <#{formatted_elapsed_time}>"
      end
      memory_usage = context[:memory_usage]
      if memory_usage > 0
        formatted_memory_usage =
          "%.2fGiB" % (memory_usage / 1024.0 / 1024.0 / 1024.0)
        formatted_message << ": memory usage: <#{formatted_memory_usage}>"
        memory_usage_diff = context[:memory_usage_diff]
        if memory_usage_diff
          formatted_memory_usage_diff =
            "%.2fMiB" % (memory_usage_diff / 1024.0 / 1024.0)
          formatted_message << ": memory usage diff: "
          formatted_message << "<#{formatted_memory_usage_diff}>"
        end
      end
      if error
        formatted_message << ": #{error.class}: #{error.message}\n"
        formatted_message << error.backtrace.join("\n")
      end
      formatted_message
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
