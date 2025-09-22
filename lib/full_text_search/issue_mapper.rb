module FullTextSearch
  class IssueMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineIssueMapper
      end

      def fts_mapper_class
        FtsIssueMapper
      end
    end
  end
  resolver.register(Issue, IssueMapper)

  class RedmineIssueMapper < RedmineMapper
    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.project_id
      tag_ids = []
      tag_ids << Tag.tracker(@record.tracker_id).id if @record.tracker_id
      fts_target.title = @record.subject
      parser = MarkupParser.new(@record.project)
      content_text, content_tag_ids = parser.parse(@record, :description)
      fts_target.content = content_text
      tag_ids.concat(content_tag_ids)
      tag_ids << Tag.user(@record.author_id).id if @record.author_id
      fts_target.is_private = @record.is_private
      tag_ids << Tag.issue_status(@record.status_id).id if @record.status_id
      fts_target.tag_ids = tag_ids
      fts_target.last_modified_at = @record.updated_on
      fts_target.registered_at = @record.created_on
      fts_target.save!

      @record.journals.each do |journal|
        redmine_mapper = JournalMapper.redmine_mapper(journal)
        # We don't insert a new FTS target here to avoid an unique
        # constraint error when a new journal is added. The following
        # jobs are enqueued when a new journal is added:
        #
        # 1. UpsertTargetJob(IssueMapper)
        # 2. UpsertTargetJob(JournalMapper)
        #
        # If both of jobs are executed in parallel, both of job 1. and
        # job 2. may try adding new FTS target for the same
        # journal. In the case, one of them is failed by an unique
        # constraint error. If we don't create a new FTS target in
        # here (job 1.), we can avoid the error.
        next unless redmine_mapper.find_fts_target.persisted?
        redmine_mapper.upsert_fts_target(options)
      end
      # @record.custom_values
    end
  end

  class FtsIssueMapper < FtsMapper
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
      "#{issue.tracker.name} \##{@record.source_id} (#{issue.status}): "
    end

    def url
      {
        controller: "issues",
        action: "show",
        id: @record.source_id,
      }
    end
  end
end
