module FullTextSearch
  module Mroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def search(query,
                 user: User.current,
                 project_ids: [],
                 scope: [],
                 attachments: "0",
                 all_words: true,
                 titles_only: false,
                 offset: nil,
                 limit: 10,
                 order_target: "score",
                 order_type: "desc",
                 query_escape: false)
        unless all_words
          query = query.split(" ").join(" OR ")
        end
        sort_direction = order_type == "desc" ? "-" : ""
        sort_keys = case order_target
                    when "score"
                      "#{sort_direction}_score"
                    when "date"
                      "#{sort_direction}original_updated_on, #{sort_direction}original_created_on"
                    end
        # mroonga_command cannot contain new line
        # mroonga_command can accept multiple arguments since 7.0.5
        # TODO use snippet_html
        if mroonga_version >= "7.05"
          query = if query_escape
                    "mroonga_escape('#{query}')"
                  else
                    "'#{query}'"
                  end
          sql = <<-SQL.strip_heredoc
          select mroonga_command(
                   'select',
                   'table', 'searcher_records',
                   'output_columns', '*,_score',
                   'drilldown', 'original_type',
                   'match_columns', '#{target_columns(titles_only).join('||')}',
                   'query', #{query},
                   'filter', '#{filter_condition(user, project_ids, scope, attachments)}',
                   'limit', '#{limit}',
                   'offset', '#{offset}',
                   'sort_keys', '#{sort_keys}'
                 )
          SQL
        else
          # FIXME escape query if query_escape is true
          sql = [
            "select mroonga_command('",
            "select --table searcher_records",
            "--output_columns *,_score",
            "--drilldown original_type",
            "--match_columns #{target_columns(titles_only).join('||')}",
            "--query \"#{query}\"",
            "--filter \\'#{filter_condition(user, project_ids, scope, attachments)}\\'",
            "--limit #{limit}",
            "--offset #{offset}",
            "--sort_keys \\'#{sort_keys}\\'",
            "'",
            ")"
          ].join(" ")
        end
        logger.debug(sql)
        r = connection.select_value(sql)
        # NOTE: Hack to use Groonga::Client::Response.parse
        # Raise Mysql2::Error if error occurred
        body = JSON.parse(r)
        header = [0, 0, 0]
        [header, body].to_json
      end

      # scope # => [:issues, :news, :documents, :changesets, :wiki_pages, :messages, :projects]
      def filter_condition(user, project_ids, scope, attachments)
        conditions = []
        unless attachments == "only"
          scope.each do |s|
            case s
            when "projects"
              if project_ids.empty?
                project_ids = if user.respond_to?(:visible_project_ids)
                                user.visible_project_ids
                              else
                                Project.visible(user).pluck(:id)
                              end
              end
              conditions << %Q[(original_type == "Project" && in_values(original_id, #{project_ids.join(',')}))] if project_ids.present?
            when "issues"
              # TODO: Support private issue
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "Issue" && is_private == false && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
              # visible_project_ids[:issue_private] = Project.allowed_to(user, :view_private_issue)
              target_ids = Project.allowed_to(user, :view_notes).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "Journal" && is_private == false && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
              target_ids = Project.allowed_to(user, :view_private_notes).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "Journal" && is_private == true && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
              target_ids = CustomField.visible(user).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "CustomValue" && in_values(custom_field_id, #{target_ids.join(',')}))] if target_ids.present?
            when "wiki_pages"
              target_ids = Project.allowed_to(user, :view_wiki_pages).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(in_values(original_type, "WikiPage", "WikiContent") && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            else
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "#{s.classify}" && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            end
          end
        end
        conditions.concat(attachments_conditions(user, project_ids, scope, attachments))
        if conditions.empty?
          ""
        else
          %Q[(#{conditions.join(' || ')})]
        end
      end

      # TODO Attachmentはコンテナごとに条件が必要。コンテナを見ることができたら検索可能にする
      # container_type: Issue, Journal, File, Document, News, WikiPage, Version, Message
      # NOTE: Version cannot have Attachment??
      def attachments_conditions(user, project_ids, scope, attachments)
        conditions = []
        case attachments
        when "0"
          # do not search attachments
        when "1", "only"
          # search attachments
          scope.each do |s|
            case s
            when "issues"
              # TODO: Filter private issue/note?
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "Attachment" && container_type == "Issue" && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
              target_ids = Project.allowed_to(user, :view_notes).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "Attachment" && container_type == "Journal" && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            when "files", "documents", "news", "wiki_pages", "messages"
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              conditions << %Q[(original_type == "Attachment" && container_type == "#{s.classify}" && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            end
          end
        end
        conditions
      end

      def mroonga_version
        return @mroonga_version if @mroonga_version
        result = connection.execute("show variables like 'mroonga_version'")
        @mroonga_version = result.to_a[0][1]
        @mroonga_version
      end
    end
  end
end
