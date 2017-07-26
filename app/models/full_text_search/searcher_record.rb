module FullTextSearch
  class SearcherRecord < ActiveRecord::Base
    attr_accessor :_score

    acts_as_event(type: :_type,
                  datetime: :_datetime,
                  title: :_title,
                  description: :_description,
                  author: :_author,
                  url: :_url)

    class << self
      def from_record(record_hash)
        h = record_hash.dup
        h.delete("_id")
        h.delete("ctid")
        new(h)
      end

      def target_columns(titles_only)
        if titles_only
          %i[name identifier title filename]
        else
          %i[
            name
            identifier
            description
            title
            summary
            subject
            comments
            content
            notes
            text
            value
            filename
          ]
        end
      end

      def target_models
        [
          Project,
          News,
          Issue,
          Document,
          Changeset,
          Message,
          Journal,
          WikiPage,
          CustomValue,
          Attachment
        ]
      end

      def container_types
        []
      end
    end

    def score
      _score
    end
    alias rank score

    def similar_search(limit: 10)
      # TODO
    end

    def original_record
      @original_record ||= original_type.constantize.find(original_id)
    end

    def project
      @project ||= Project.find(project_id)
    end

    def _type
      case original_type
      when "Issue"
        issue = original_record
        "issue" + (issue.closed? ? "-closed" : "")
      when "Journal"
        journal = original_record
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
      when "Message"
        message = original_record
        if message.parend_id.nil?
          "message"
        else
          "reply"
        end
      when "WikiContent"
        "wiki-page"
      else
        original_type.underscore.dasherize
      end
    end

    def _datetime
      case original_type
      when "Changeset"
        commited_on
      when "WikiContent"
        original_updated_on
      else # Attachment
        original_created_on
      end
    end

    def _title
      case original_type
      when "Attachment"
        filename
      when "Document"
        "#{l(:label_document)}: #{o.title}"
      when "Issue"
        issue = original_record
        "#{issue.tracker.name} ##{original_id} #{issue.status}: #{subject}"
      when "Journal"
        journal = original_record
        issue = journal.issue
        "#{issue.tracker.name} ##{issue.id}#{issue.status}: #{issue.subject}"
      when "Message"
        "#{board_name}: #{subject}"
      when "Project"
        "#{l(:label_project)}: #{name}"
      when "WikiPage"
        "#{l(:label_wiki)}: #{title}"
      else
        title
      end
    end

    def _description
      case original_type
      when "Changeset"
        long_comments
      when "Journal"
        notes
      when "Message"
        content
      when "WikiPage"
        text
      when "WikiContent"
        comments
      else
        description
      end
    end

    def _author
      # Not in use /search
      nil
    end

    def _url
      case original_type
      when "Attachment"
        { controller: "attachments", action: "show", id: original_id, filename: filename }
      when "Changeset"
        changeset = original_record
        { controller: "repositories", action: "revision", id: project, repository_id: changeset.repository.identifier_param, rev: changeset.identifier }
      when "Document"
        { controller: "documents", action: "show", id: original_id }
      when "Issue"
        { controller: "issues", action: "show", id: original_id }
      when "Journal"
        journal = original_record
        { controller: "issues", action: "show", id: journal.issue.id, anchor: "change-#{original_id}" }
      when "News"
        { controller: "news", action: "show", id: original_id }
      when "Project"
        { controller: "projects", action: "show", id: original_id }
      when "WikiContent"
        { controller: "wiki", action: "show", project_id: project, id: title, version: version }
      when "WikiPage"
        { controller: "wiki", action: "show", project_id: project, id: title }
      else
        { controller: "welcome" }
      end
    end

    def event_group
      # Not in use /search
    end
  end
end
