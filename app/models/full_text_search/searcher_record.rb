module FullTextSearch
  class SearcherRecord < ActiveRecord::Base
    extend FullTextSearch::ConditionBuilder

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
      def from_record(record_hash)
        h = record_hash.dup
        h.delete("_id")
        h.delete("ctid")
        new(h)
      end

      def target_columns(titles_only)
        if titles_only
          %w[name identifier title subject filename]
        else
          %w[
            name*100
            identifier*100
            title*100
            subject*100
            filename*100
            description
            summary
            comments
            content
            notes
            text
            value
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

      def digest_columns
        title_digest("title_digest", %w(subject title filename name short_comments)) +
          description_digest("description_digest", %w(content text notes description summary value long_comments))
      end

      def dynamic_columns
        digest_columns +
          calculated_updated_on("calculated_updated_on", %w(original_created_on original_updated_on))
      end

      # scope # => [:issues, :news, :documents, :changesets, :wiki_pages, :messages, :projects]
      def _filter_condition(user, project_ids, scope, attachments, open_issues)
        conditions = []

        if project_ids.empty?
          project_ids = if user.respond_to?(:visible_project_ids)
                          user.visible_project_ids
                        else
                          Project.visible(user).pluck(:id)
                        end
          return [] if project_ids.empty?
        end

        unless attachments == "only"
          scope.each do |s|
            case s
            when "projects"
              if project_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Project"',
                                              "in_values(original_id, #{project_ids.join(',')})")
              end
              target_ids = CustomField.visible(user).pluck(:id)
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "CustomValue"',
                                              "in_values(custom_field_id, #{target_ids.join(',')})")
              end
            when "issues"
              # TODO: Support private issue
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Issue"',
                                              "is_private == false",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
              # visible_project_ids[:issue_private] = Project.allowed_to(user, :view_private_issue)
              # We can see journals for visible issues
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Journal"',
                                              "private_notes == false",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
              target_ids = Project.allowed_to(user, :view_private_notes).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Journal"',
                                              "private_notes == true",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
              target_ids = CustomField.visible(user).pluck(:id)
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "CustomValue"',
                                              "is_private == false",
                                              "in_values(project_id, #{project_ids.join(',')})",
                                              "in_values(custom_field_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
            when "wiki_pages"
              target_ids = Project.allowed_to(user, :view_wiki_pages).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'in_values(original_type, "WikiPage", "WikiContent")',
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            else
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              %Q[original_type == "#{s.classify}"],
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            end
          end
        end
        conditions.concat(attachments_conditions(user, project_ids, scope, attachments, open_issues))
      end

      # TODO Attachmentはコンテナごとに条件が必要。コンテナを見ることができたら検索可能にする
      # container_type: Issue, Journal, File, Document, News, WikiPage, Version, Message
      def attachments_conditions(user, project_ids, scope, attachments, open_issues)
        conditions = []
        case attachments
        when "0"
          # do not search attachments
        when "1", "only"
          # search attachments
          scope.each do |s|
            case s
            when "issues"
              # TODO: Support private issue?
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Attachment"',
                                              'container_type == "Issue"',
                                              "is_private == false",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
            when "projects", "versions"
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Attachment"',
                                              'in_values(container_type, "Project", "Version")',
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            when "documents", "news", "wiki_pages", "messages"
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition("&&",
                                              'original_type == "Attachment"',
                                              %Q[container_type == "#{s.classify}"],
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            end
          end
        end
        conditions
      end

      def open_issues_condition(open_issues)
        return nil unless open_issues
        @status_ids ||= IssueStatus.where(is_closed: false).pluck(:id)
        "in_values(status_id, #{@status_ids.join(',')})"
      end
    end

    def score
      _score
    end
    alias rank score

    def original_record
      @original_record ||= case original_type
                           when "WikiPage", "wikipage"
                             WikiPage.find(original_id)
                           when "CustomValue", "customvalue"
                             CustomValue.find(original_id)
                           else
                             # "Project", "project"
                             # "News", "news"
                             # "Issue", "issue"
                             # "Document", "document"
                             # "Changeset", "changeset"
                             # "Message", "message"
                             # "Journal", "journal"
                             # "Attachment", "attachment"
                             original_type.capitalize.constantize.find(original_id)
                           end
    end

    def project
      @project ||= Project.find(project_id)
    end

    def _type
      case original_type
      when "Issue", "issue"
        issue = original_record
        "issue" + (issue.closed? ? "-closed" : "")
      when "Journal", "journal"
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
      when "Message", "message"
        message = original_record
        if message.parent_id.nil?
          "message"
        else
          "reply"
        end
      when "WikiContent", "wikicontent"
        "wiki-page"
      when "CustomValue", "customvalue"
        original_record.customized.event_type
      else
        original_type.underscore.dasherize
      end
    end

    def _datetime
      [original_created_on, original_updated_on].max
    end

    def _title
      case original_type
      when "Attachment", "attachment"
        "#{title_prefix}#{filename}"
      when "Document", "document"
        "#{title_prefix}#{title}"
      when "Issue", "issue"
        "#{title_prefix} #{subject}"
      when "Journal", "journal"
        journal = original_record
        issue = journal.issue
        "#{title_prefix}#{issue.subject}"
      when "Message", "message"
        "#{title_prefix}#{subject}"
      when "Project", "project"
        "#{title_prefix}#{name}"
      when "WikiPage", "wikipage"
        "#{title_prefix}#{title}"
      when "Changeset", "changeset"
        "#{title_prefix}#{short_comments}"
      when "CustomValue", "customvalue"
        original_record.customized.event_title
      else
        title
      end
    end

    def _description
      case original_type
      when "Journal", "journal"
        notes
      when "Message", "message"
        content
      when "WikiPage", "wikipage"
        text
      when "Changeset", "changeset"
        long_comments.presence || comments
      when "CustomValue", "customvalue"
        original_record.customized.event_description
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
      when "Attachment", "attachment"
        { controller: "attachments", action: "show", id: original_id, filename: filename }
      when "Changeset", "changeset"
        changeset = original_record
        { controller: "repositories", action: "revision", id: project, repository_id: changeset.repository.identifier_param, rev: changeset.identifier }
      when "Document", "document"
        { controller: "documents", action: "show", id: original_id }
      when "Issue", "issue"
        { controller: "issues", action: "show", id: original_id }
      when "Journal", "journal"
        journal = original_record
        { controller: "issues", action: "show", id: journal.issue.id, anchor: "change-#{original_id}" }
      when "News", "news"
        { controller: "news", action: "show", id: original_id }
      when "Message", "message"
        message = original_record
        { controller: "messages", action: "show", board_id: message.board.id, id: original_id }
      when "Project", "project"
        { controller: "projects", action: "show", id: original_id }
      when "WikiPage", "wikipage"
        { controller: "wiki", action: "show", project_id: project, id: title }
      when "CustomValue", "customvalue"
        original_record.customized.event_url
      else
        { controller: "welcome" }
      end
    end

    def event_group
      # Not in use /search
    end

    def title_prefix
      case original_type
      when "Attachment", "attachment"
        ""
      when "Changeset", "changeset"
        c = original_record
        repo = (c.repository && c.repository.identifier.present?) ? " (#{c.repository.identifier})" : ''
        delimiter = short_comments.blank? ? '' : ': '
        "#{l(:label_revision)} #{c.format_identifier}#{repo}#{delimiter}"
      when "Document", "document"
        "#{l(:label_document)}: "
      when "Issue", "issue"
        issue = original_record
        "#{issue.tracker.name} ##{original_id} (#{issue.status}): "
      when "Journal", "journal"
        journal = original_record
        issue = journal.issue
        "#{issue.tracker.name} ##{issue.id} (#{issue.status}): "
      when "Message", "message"
        "#{original_record.board.name}: "
      when "Project", "project"
        "#{l(:label_project)}: "
      when "WikiPage", "wikipage"
        "#{l(:label_wiki)}: "
      else
        ""
      end
    end

    def event_title_digest
      @vent_title_digest ||= if title_digest.present?
                                "#{title_prefix}#{title_digest}".html_safe
                              else
                                event_title
                              end
    end

    def event_description_digest
      @event_description_digest ||= if description_digest.select(&:present?).present?
                                       description_digest.join(" &hellip; ").html_safe
                                     else
                                       event_description.truncate(255)
                                     end
    end
  end
end
