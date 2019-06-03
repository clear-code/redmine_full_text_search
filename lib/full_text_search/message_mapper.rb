module FullTextSearch
  class MessageMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineMessageMapper
      end

      def fts_mapper_class
        FtsMessageMapper
      end
    end
  end
  resolver.register(Message, MessageMapper)

  class RedmineMessageMapper < RedmineMapper
    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.board.project_id
      fts_target.title = @record.subject
      fts_target.content = @record.content
      fts_target.last_modified_at = @record.updated_on
      fts_target.save!
    end
  end

  class FtsMessageMapper < FtsMapper
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
