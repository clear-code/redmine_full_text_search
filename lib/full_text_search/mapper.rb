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
        FullTextSearch::UpsertTargetJob.perform_later(name, record.id)
      end

      def after_destroy(record)
        mapper = redmine_mapper(record)
        mapper.destroy_fts_target
      end

      def redmine_class
        FullTextSearch.resolver.resolve(self)
      end

      def not_mapped_redmine_records(options={})
        redmine_mapper_class.not_mapped(redmine_class, options)
      end

      def orphan_fts_targets(options={})
        fts_mapper_class.orphan(redmine_class, options)
      end

      def outdated_fts_targets(options={})
        fts_mapper_class.outdated(redmine_class, options)
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
      def with_project(redmine_class)
        redmine_class.joins(:project)
      end

      def not_mapped(redmine_class, options={})
        targets =
          Target
            .where(source_type_id: Type[redmine_class].id)
            .select(:source_id)
        records =
          with_project(redmine_class)
            .where.not(id: targets)
        project = options[:project]
        if project
          records
            .where(project.project_condition(true))
        else
          records
            .where(projects: {status: not_archived_project_statuses})
        end
      end

      def need_text_extraction?
        method_defined?(:extract_text)
      end

      private
      def not_archived_project_statuses
        [Project::STATUS_ACTIVE, Project::STATUS_CLOSED]
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
      # We need to destroy targets for custom values because
      # custom values are associated with "dependent: :delete_all".
      Target.where(source_type_id: Type.custom_value.id,
                   container_id: @record.id,
                   container_type_id: Type[@record].id).destroy_all
    end

    private
    def fts_target_keys
      {
        source_id: @record.id,
        source_type_id: Type[@record].id,
      }
    end

    def prepare_text_extraction(fts_target)
      fts_target.tag_ids += [Tag.text_extraction_yet.id]
    end

    def set_extracted_content(fts_target, content, prepended_contents=[])
      fts_target.tag_ids -= Tag.text_extraction_ids
      fts_target.tag_ids += [Tag.text_extraction_error.id] if content.nil?
      contents = prepended_contents + [content.presence]
      fts_target.content = contents.compact.join("\n")
    end

    def extract_tag_ids_from_path(path)
      extension = File.extname(path).gsub(/\A\./, "")
      return [] if extension.empty?
      [Tag.extension(extension).id]
    end

    def extract_content(fts_target, options)
      case options[:extract_text] || :immediate
      when :immediate
        extract_text
      when :later
        ExtractTextJob.perform_later(fts_target.id)
      end
    end

    def run_text_extractor(fts_target, metadata)
      tracer = Tracer.new("[text-extract]")
      trace_data = [
        ["FullTextSearch::Target", fts_target.id],
        [@record.class.name, @record.id],
      ]
      trace_data.concat(metadata)
      begin
        extractor = TextExtractor.new
        content = yield(extractor)
        tracer.trace(:info, "Extracted", trace_data)
        content
      rescue => error
        tracer.trace(:error,
                     "Failed to extract text",
                     trace_data,
                     error: error)
        nil
      rescue NoMemoryError => error
        tracer.trace(:error,
                     "Failed to extract text by no memory",
                     trace_data,
                     error: error)
        nil
      end
    end
  end

  class FtsMapper
    include Rails.application.routes.url_helpers
    include Redmine::I18n

    class << self
      def orphan(redmine_class, options={})
        targets =
          Target
            .where(source_type_id: Type[redmine_class].id)
            .joins(<<-JOIN)
LEFT OUTER JOIN #{redmine_class.table_name}
  ON #{redmine_class.table_name}.id =
     #{Target.table_name}.source_id
            JOIN
        redmine_mapper_class =
          FullTextSearch.resolver.resolve(redmine_class).redmine_mapper_class
        archived_projects =
          Project
            .where(status: Project::STATUS_ARCHIVED)
        archived_sources =
          redmine_mapper_class
            .with_project(redmine_class)
            .where(projects: {id: archived_projects})
        no_source_targets =
          targets.where(redmine_class.table_name => {id: nil})
        archived_source_targets =
          targets.where(redmine_class.table_name => {id: archived_sources})
        no_source_targets.or(archived_source_targets)
      end

      def outdated(redmine_class, options={})
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
      "#{title_prefix}#{title_content}#{title_suffix}"
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

    def title_content
      @record.title
    end

    def title_suffix
      ""
    end
  end
end
