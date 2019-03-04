module FullTextSearch
  class MessageMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineMessageMapper
      end

      def searcher_mapper_class
        SearcherMessageMapper
      end
    end
  end
  resolver.register(Message, MessageMapper)

  class RedmineMessageMapper < RedmineMapper
    def upsert_searcher_record(options={})
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.board.project_id
      searcher_record.project_name = @record.board.project.name
      searcher_record.subject = @record.subject
      searcher_record.content = @record.content
      searcher_record.original_created_on = @record.created_on
      searcher_record.original_updated_on = @record.updated_on
      searcher_record.save!
    end
  end

  class SearcherMessageMapper < SearcherMapper
    def type
      message = redmine_record
      if message.parent_id.nil?
        "message"
      else
        "reply"
      end
    end

    def title_prefix
      message = redmine_record
      "#{message.board.name}: "
    end

    def title
      "#{title_prefix}#{@record.subject}"
    end

    def description
      @record.content
    end

    def url
      message = redmine_record
      {
        controller: "messages",
        action: "show",
        board_id: message.board.id,
        id: message.id,
      }
    end
  end
end
