module FullTextSearch
  class UpdateIssueContentJob < ActiveJob::Base
    queue_as :full_text_search
    queue_with_priority 15

    discard_on ActiveRecord::RecordNotFound

    def perform(record_class_name, record_id, action)
      record_class = record_class_name.constantize
      record = record_class.find(record_id)

      case action
      when "save"
        case record
        when Issue
          content = FullTextSearch::IssueContent
                      .find_or_initialize_by(issue_id: record.id)
          content.project_id = record.project_id
          content.subject = record.subject
          content.contents = create_contents(record.id)
          content.status_id = record.status_id
          content.is_private = record.is_private
          content.save!
        when Journal
          issue_id = record.journalized_id
          FullTextSearch::IssueContent
            .where(issue_id: issue_id)
            .update_all(contents: create_contents(issue_id))
        end
      when "destroy"
        case record
        when Issue
          FullTextSearch::IssueContent.where(issue_id: record.id).destroy_all
        when Journal
          issue_id = record.journalized_id
          FullTextSearch::IssueContent
            .where(issue_id: issue_id)
            .update_all(contents: create_contents(issue_id, excludes: [record.id]))
        end
      end
    end

    private
    def create_contents(issue_id, excludes: [])
      issue = Issue.eager_load(:journals).find(issue_id)
      contents = [issue.subject, issue.description]
      notes = issue.journals
                .reject {|j| j.notes.blank? || excludes.include?(j.id) }
                .sort_by(&:id)
                .map(&:notes)
      contents.concat(notes)
      contents.join("\n")
    end
  end
end
