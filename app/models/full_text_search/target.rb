module FullTextSearch
  class Target < ApplicationRecord
    self.table_name = :fts_targets

    if respond_to?(:connection_db_config)
      adapter = connection_db_config.adapter
    else
      adapter = connection_config[:adapter]
    end
    case adapter
    when "postgresql"
      include Pgroonga
    when "mysql2"
      include Mroonga
      attribute :tag_ids,
                MroongaIntegerArrayType.new(mroonga_vector_load_is_supported?)
      unless mroonga_vector_load_is_supported?
        around_save :tag_ids_around_save
        private def tag_ids_around_save
          if tag_ids_changed?
            raw_tag_ids = tag_ids.dup
            yield
            values = [
              {"_key" => id, "tag_ids" => raw_tag_ids},
            ]
            arguments = {
              "values" => values.to_json,
            }
            command = Groonga::Command::Load.new("load", arguments)
            self.class.select(command)
          else
            yield
          end
        end
      end
    end

    @highlight_keyword_extraction_is_broken = nil
    @use_slices = nil
    class << self
      def highlight_keyword_extraction_is_broken?
        if @highlight_keyword_extraction_is_broken.nil?
          @highlight_keyword_extraction_is_broken =
            (Gem::Version.new(groonga_version) <
             Gem::Version.new("9.0.5"))
        end
        @highlight_keyword_extraction_is_broken
      end

      def use_slices?
        if @use_slices.nil?
          @use_slices = (Gem::Version.new(groonga_version) >=
                         Gem::Version.new("9.0.7"))
        end
        @use_slices
      end

      def truncate
        connection.truncate(table_name)
      end

      def pgroonga_index_name
        "fts_targets_index_pgroonga"
      end
    end

    scope :attachments,   -> {where(source_type_id: Type.attachment.id)}
    scope :changes,       -> {where(source_type_id: Type.change.id)}
    scope :changesets,    -> {where(source_type_id: Type.changeset.id)}
    scope :custom_values, -> {where(source_type_id: Type.custom_value.id)}
    scope :documents,     -> {where(source_type_id: Type.document.id)}
    scope :files,         -> {where(source_type_id: Type.file.id)}
    scope :issues,        -> {where(source_type_id: Type.issue.id)}
    scope :journals,      -> {where(source_type_id: Type.journal.id)}
    scope :messages,      -> {where(source_type_id: Type.message.id)}
    scope :news,          -> {where(source_type_id: Type.news.id)}
    scope :projects,      -> {where(source_type_id: Type.project.id)}
    scope :repositories,  -> {where(source_type_id: Type.repository.id)}
    scope :versions,      -> {where(source_type_id: Type.version.id)}
    scope :wiki_pages,    -> {where(source_type_id: Type.wiki_page.id)}

    attr_accessor :_score
    attr_accessor :highlighted_title
    attr_accessor :content_snippets

    acts_as_event(type: :_type,
                  datetime: :_datetime,
                  title: :_title,
                  description: :_description,
                  author: :_author,
                  url: :_url)

    def score
      _score
    end
    alias rank score

    def mapper
      @mapper ||= FullTextSearch.resolver.resolve(self)
    end

    def source_record
      @source_record ||= mapper.redmine_record
    end

    def project
      @project ||= Project.find(project_id)
    end

    def _type
      mapper.type
    end

    def _datetime
      mapper.datetime
    end

    def _title
      mapper.title
    end

    def _description
      mapper.description
    end

    def _author
      # Not in use /search
      nil
    end

    def _url
      mapper.url
    end

    def event_group
      # Not in use /search
      nil
    end

    def event_id
      mapper.id
    end

    def event_highlighted_title
      @event_highlighted_title ||=
        if highlighted_title.present?
          "#{h(mapper.title_prefix)}#{highlighted_title}#{h(mapper.title_suffix)}".html_safe
        else
          h(event_title).html_safe
        end
    end

    def event_content_snippets
      @event_content_snippets ||=
        if content_snippets.present?
          content_snippets
        else
          [h((event_description || "").truncate(255)).html_safe]
        end
    end

    def tags
      Tag.where(id: tag_ids || [])
    end

    private
    def h(string)
      CGI.escape_html(string)
    end
  end
end
