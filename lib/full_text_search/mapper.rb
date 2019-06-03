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
          mapper.upsert_fts_target
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
        source_type_id: Type.__send__(@record.class.name.underscore).id,
      }
    end

    def extract_tag_ids_from_path(path)
      extension = File.extname(path).delete_prefix(".")
      return [] if extension.empty?
      [Tag.extension(extension).id]
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
