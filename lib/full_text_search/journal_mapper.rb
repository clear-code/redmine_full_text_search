module FullTextSearch
  class JournalMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineJournalMapper
      end

      def searcher_mapper_class
        SearcherJournalMapper
      end
    end
  end
  resolver.register(Journal, JournalMapper)

  class RedmineJournalMapper < RedmineMapper
    def upsert_searcher_record(options={})
      # journal belongs to an issue for now.
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.journalized.project_id
      searcher_record.project_name = @record.journalized.project.name
      searcher_record.issue_id = @record.journalized_id
      searcher_record.notes = @record.notes
      searcher_record.author_id = @record.user_id
      searcher_record.private_notes = @record.private_notes
      searcher_record.status_id = @record.journalized.status_id
      searcher_record.original_created_on = @record.created_on
      searcher_record.save!
    end
  end

  class SearcherJournalMapper < SearcherMapper
    def type
      journal = redmine_record
      new_status = journal.new_status
      if new_status
        if new_status.is_closed?
          "issue-closed"
        else
          "issue-edit"
        end
      else
        "issue-note"
      end
    end

    def title_prefix
      journal = redmine_record
      issue = journal.issue
      "#{issue.tracker.name} \##{issue.id} (#{issue.status}): "
    end

    def title
      journal = redmine_record
      issue = journal.issue
      "#{title_prefix}#{issue.subject}"
    end

    def description
      @record.notes
    end

    def url
      journal = redmine_record
      {
        controller: "issues",
        action: "show",
        id: journal.issue.id,
        anchor: "change-#{journal.id}",
      }
    end
  end
end
