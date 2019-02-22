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
      def sync
        destroy_all
        FullTextSearch.resolver.each do |redmine_class, mapper_class|
          redmine_class.find_each do |record|
            mapper = mapper_class.redmine_mapper(record)
            mapper.upsert_searcher_record
          end
        end
      end

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

      # TODO: Attachment needs conditions for each container. We can
      # make attachment searchable when we can confirma container.
      #
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

    def mapper
      @mapper ||= FullTextSearch.resolver.resolve(self)
    end

    def original_record
      @original_record ||= mapper.redmine_record
    end

    def project
      @project ||= Project.find(project_id)
    end

    def _type
      mapper.type
    end

    def _datetime
      [original_created_on, original_updated_on].max
    end

    def _title
      mapper.title
    end

    def _description
      mapper.description
    end

    def _author
      # Not in use /search
      nil
    end

    def _url
      mapper.url
    end

    def event_group
      # Not in use /search
      nil
    end

    def event_title_digest
      @event_title_digest ||= if title_digest.present?
                                "#{mapper.title_prefix}#{title_digest}".html_safe
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
