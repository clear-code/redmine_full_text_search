module FullTextSearch
  class IssueMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineIssueMapper
      end

      def searcher_mapper_class
        SearcherIssueMapper
      end
    end
  end
  resolver.register(Issue, IssueMapper)

  class RedmineIssueMapper < RedmineMapper
    def upsert_searcher_record
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.project_id
      searcher_record.project_name = @record.project.name
      searcher_record.tracker_id = @record.tracker_id
      searcher_record.issue_id = @record.id
      searcher_record.subject = @record.subject
      searcher_record.description = @record.description
      searcher_record.author_id = @record.author_id
      searcher_record.is_private = @record.is_private
      searcher_record.status_id = @record.status_id
      searcher_record.original_created_on = @record.created_on
      searcher_record.original_updated_on = @record.updated_on
      searcher_record.save!
    end
  end

  class SearcherIssueMapper < SearcherMapper
    def type
      issue = redmine_record
      if issue.closed?
        "issue-closed"
      else
        "issue"
      end
    end

    def title_prefix
      issue = redmine_record
      "#{issue.tracker.name} \##{@record.original_id} (#{issue.status}): "
    end

    def title
      "#{title_prefix}#{@record.subject}"
    end

    def url
      {
        controller: "issues",
        action: "show",
        id: @record.original_id,
      }
    end
  end
end
