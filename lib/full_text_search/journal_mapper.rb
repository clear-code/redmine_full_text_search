module FullTextSearch
  class JournalMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineJournalMapper
      end

      def fts_mapper_class
        FtsJournalMapper
      end
    end
  end
  resolver.register(Journal, JournalMapper)

  class RedmineJournalMapper < RedmineMapper
    class << self
      def with_project(redmine_class)
        redmine_class
          .joins(<<-JOIN)
JOIN issues
  ON journalized_type = 'Issue' AND issues.id = journalized_id
          JOIN
          .joins(<<-JOIN)
JOIN projects
  ON projects.id = issues.project_id
          JOIN
      end
    end

    def upsert_fts_target(options={})
      # journal belongs to an issue for now.
      issue = @record.issue
      return if issue.nil?
      return unless issue.is_a?(Issue)

      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = issue.project_id
      fts_target.container_id = issue.id
      fts_target.container_type_id = Type.issue.id
      tag_ids = []
      parser = MarkupParser.new(issue.project)
      content_text, content_tag_ids = parser.parse(@record, :notes)
      fts_target.content = content_text
      tag_ids.concat(content_tag_ids)
      tag_ids << Tag.user(@record.user_id).id if @record.user_id
      fts_target.is_private = (issue.is_private or @record.private_notes)
      tag_ids << Tag.tracker(issue.tracker_id).id if issue.tracker_id
      tag_ids << Tag.issue_status(issue.status_id).id if issue.status_id
      fts_target.tag_ids = tag_ids
      fts_target.last_modified_at = @record.created_on
      fts_target.save!
    end
  end

  class FtsJournalMapper < FtsMapper
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
      prefix = "#{issue.tracker.name} "
      prefix << "\##{issue.id}\#change-#{journal.id} "
      prefix << "(#{issue.status}): "
      prefix
    end

    def title
      journal = redmine_record
      issue = journal.issue
      "#{title_prefix}#{issue.subject}#{title_suffix}"
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
