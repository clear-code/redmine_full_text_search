module FullTextSearch
  class UpdateIssueContentJob < ActiveJob::Base
    queue_as :full_text_search
    queue_with_priority 15

    discard_on ActiveRecord::RecordNotFound

    def perform(record_class_name, record_id, action, options={})
      record_class = record_class_name.constantize

      case action
      when "commit"
        record = record_class.find(record_id)
        case record
        when Issue
          content = FullTextSearch::IssueContent
                      .find_or_initialize_by(issue_id: record.id)
          content.project_id = record.project_id
          content.subject = record.subject
          content.content = create_content(record.id)
          content.status_id = record.status_id
          content.save!
        when Journal
          issue_id = record.journalized_id
          FullTextSearch::IssueContent
            .where(issue_id: issue_id)
            .update_all(content: create_content(issue_id))
        end
      when "destroy"
        case record_class_name
        when "Issue"
          FullTextSearch::IssueContent.where(issue_id: record_id).destroy_all
        when "Journal"
          issue_id = options[:issue_id]
          FullTextSearch::IssueContent
            .where(issue_id: issue_id)
            .update_all(content: create_content(issue_id, excludes: [record_id]))
        when "Attachment"
          issue_id = options[:issue_id]
          FullTextSearch::IssueContent
            .where(issue_id: issue_id)
            .update_all(content: create_content(issue_id))
        end
      end
    end

    private
    def create_content(issue_id, excludes: [])
      issue = Issue.eager_load(:journals).find(issue_id)
      content = [issue.subject, issue.description]
      notes = issue.journals
                .reject {|j| j.notes.blank? || excludes.include?(j.id) }
                .sort_by(&:id)
                .map(&:notes)
      content.concat(notes)
      issue.attachments.order(:id).each do |attachment|
        content << attachment.filename if attachment.filename.present?
        content << attachment.description if attachment.description.present?
      end
      content.join("\n")
    end
  end
end
