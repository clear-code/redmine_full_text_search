module FullTextSearch
  class SearcherRecord < ActiveRecord::Base
    case connection_config[:adapter]
    when "postgresql"
      require_dependency "full_text_search/pgroonga"
      include FullTextSearch::PGroonga
    when "mysql2"
      require_dependency "full_text_search/mroonga"
      include FullTextSearch::Mroonga
    end

    attr_accessor :_score
    attr_accessor :title_digest, :description_digest
    attr_accessor :calculated_updated_on

    acts_as_event(type: :_type,
                  datetime: :_datetime,
                  title: :_title,
                  description: :_description,
                  author: :_author,
                  url: :_url)

    class << self
      def pgroonga_index_name
        "index_searcher_records_pgroonga"
      end
    end

    def score
      _score
    end
    alias rank score

    def mapper
      @mapper ||= FullTextSearch.resolver.resolve(self)
    end

    def original_record
      @original_record ||= mapper.redmine_record
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

    def event_title_digest
      @event_title_digest ||=
        if title_digest.present?
          "#{mapper.title_prefix}#{title_digest}#{mapper.title_suffix}".html_safe
        else
          event_title
        end
    end

    def event_description_digest
      @event_description_digest ||=
        if description_digest.select(&:present?).present?
          description_digest.join(" &hellip; ").html_safe
        else
          (event_description || "").truncate(255)
        end
    end
  end
end
