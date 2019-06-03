module FullTextSearch
  class Target < ActiveRecord::Base
    self.table_name = :fts_targets

    case connection_config[:adapter]
    when "postgresql"
      require_dependency "full_text_search/pgroonga"
      include PGroonga
    when "mysql2"
      require_dependency "full_text_search/mroonga"
      include Mroonga
      attribute :tag_ids, MroongaIntegerArrayType.new
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
          Target.select(command)
        else
          yield
        end
      end
    end

    attr_accessor :_score
    attr_accessor :highlighted_title
    attr_accessor :content_snippets

    acts_as_event(type: :_type,
                  datetime: :_datetime,
                  title: :_title,
                  description: :_description,
                  author: :_author,
                  url: :_url)

    class << self
      def pgroonga_index_name
        "fts_targets_index_pgroonga"
      end
    end

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

    private
    def h(string)
      CGI.escape_html(string)
    end
  end
end
