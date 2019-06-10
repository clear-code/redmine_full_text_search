module FullTextSearch
  class Mapper
    class << self
      def attach(redmine_class)
        mapper_class = self
        redmine_class.class_eval do
          after_commit mapper_class, on: [:create, :update]
          after_destroy mapper_class
          define_method(:to_fts_target) do
            mapper_class.redmine_mapper(self).find_fts_target
          end
        end
      end

      def after_commit(record)
        begin
          mapper = redmine_mapper(record)
          mapper.upsert_fts_target(extract_text: :later)
        rescue => error
          Rails.logger.error do
            message = "[full-text-search] Failed to upsert FTS target: "
            message << "#{error.class}: #{error.message}\n"
            message << error.backtrace.join("\n")
            message
          end
        end
      end

      def after_destroy(record)
        mapper = redmine_mapper(record)
        mapper.destroy_fts_target
      end

      def redmine_class
        FullTextSearch.resolver.resolve(self)
      end

      def not_mapped_redmine_records
        redmine_mapper_class.not_mapped(redmine_class)
      end

      def orphan_fts_targets
        fts_mapper_class.orphan(redmine_class)
      end

      def outdated_fts_targets
        fts_mapper_class.outdated(redmine_class)
      end

      def redmine_mapper(record)
        redmine_mapper_class.new(self, record)
      end

      def fts_mapper(record)
        fts_mapper_class.new(self, record)
      end

      def need_text_extraction?
        redmine_mapper_class.need_text_extraction?
      end
    end
  end

  class RedmineMapper
    class << self
      def not_mapped(redmine_class)
        targets =
          Target
            .where(source_type_id: Type[redmine_class].id)
            .select(:source_id)
        redmine_class
          .where.not(id: targets)
          .order(id: :asc)
      end

      def need_text_extraction?
        method_defined?(:extract_text)
      end
    end

    def initialize(mapper, record)
      @mapper = mapper
      @record = record
    end

    def find_fts_target
      Target.find_or_initialize_by(fts_target_keys)
    end

    def destroy_fts_target
      Target.where(fts_target_keys).destroy_all
    end

    private
    def fts_target_keys
      {
        source_id: @record.id,
        source_type_id: Type[@record.class].id,
      }
    end

    def extract_tag_ids_from_path(path)
      extension = File.extname(path).delete_prefix(".")
      return [] if extension.empty?
      [Tag.extension(extension).id]
    end

    def extract_content(fts_target, options)
      case options[:extract_text]
      when :immediate
        extract_text
      when :later
        ExtractTextJob.perform_later(fts_target.id)
      end
    end

    def run_text_extractor(fts_target, metadata)
      before_memory_usage = memory_usage
      start_time = Time.now
      context = {
        fts_target: fts_target,
        content: nil,
        memory_usage: before_memory_usage,
        metadata: metadata,
      }
      Rails.logger.info do
        format_log_message("Extracting...", context)
      end
      begin
        extractor = TextExtractor.new
        context[:content] = yield(extractor)
      rescue => error
        Rails.logger.error do
          format_log_message("Failed to extract text",
                             context,
                             error)
        end
        return nil
      rescue NoMemoryError => error
        Rails.logger.error do
          format_log_message("Failed to extract text by no memory",
                             context,
                             error)
        end
        return nil
      end
      context[:elapsed_time] = Time.now - start_time
      after_memory_usage = memory_usage
      context[:memory_usage_diff] = after_memory_usage - before_memory_usage
      context[:memory_usage] = after_memory_usage
      Rails.logger.info do
        format_log_message("Extracted", context)
      end
      context[:content]
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
      formatted_message << "#{@record.class.name}: #{@record.id}"
      if context[:metadata]
        context[:metadata].each do |label, value|
          formatted_message << ": #{label}: <#{value}>"
        end
      end
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

  class FtsMapper
    include Rails.application.routes.url_helpers
    include Redmine::I18n

    class << self
      def orphan(redmine_class)
        Target
          .where(source_type_id: Type[redmine_class].id)
          .joins(<<-SQL)
LEFT OUTER JOIN #{redmine_class.table_name}
  ON #{redmine_class.table_name}.id =
     #{Target.table_name}.source_id
          SQL
          .where(redmine_class.table_name => {id: nil})
      end

      def outdated(redmine_class)
        unless redmine_class.column_names.include?("updated_on")
          return Target.none
        end

        Target
          .where(source_type_id: Type[redmine_class].id)
          .joins(<<-SQL)
JOIN #{redmine_class.table_name}
  ON #{redmine_class.table_name}.id =
     #{Target.table_name}.source_id
          SQL
          .where(<<-SQL)
#{Target.table_name}.last_modified_at <
#{redmine_class.table_name}.updated_on
          SQL
      end
    end

    def initialize(mapper, record)
      @mapper = mapper
      @record = record
    end

    def redmine_record
      @redmine_record ||=
        FullTextSearch.resolver.resolve(@mapper).find(@record.source_id)
    end

    def redmine_mapper
      @mapper.redmine_mapper(redmine_record)
    end

    def type
      Type.find(@record.source_type_id).name.underscore.dasherize
    end

    def title
      "#{title_prefix}#{@record.title}#{title_suffix}"
    end

    def description
      @record.content
    end

    def url
      {
        controller: "welcome",
      }
    end

    def id
      @record.source_id
    end

    def datetime
      @record.last_modified_at
    end

    def title_prefix
      ""
    end

    def title_suffix
      ""
    end
  end
end
