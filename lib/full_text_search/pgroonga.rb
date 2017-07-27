module FullTextSearch
  module PGroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      #
      #
      # @params order_target "score" or "date"
      # @params order_type   "desc" or "asc"
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
                 order_type: "desc")
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
        sql = <<-SQL
          select pgroonga.command(
                   'select',
                   ARRAY[
                     'table', pgroonga.table_name('#{index_name}'),
                     'output_columns', '*,_score',
                     'drilldown', 'original_type',
                     'match_columns', '#{target_columns(titles_only).join(",")}',
                     'query', pgroonga.query_escape('#{query}'),
                     'filter', '#{filter_condition(user, project_ids, scope, attachments)}',
                     'limit', '#{limit}',
                     'offset', '#{offset}',
                     'sort_keys', '#{sort_keys}'
                   ]
                 )::json
        SQL
        logger.debug(sql)
        connection.select_value(sql)
      end

      def index_name
        "index_searcher_records_pgroonga"
      end

      def pgroonga_table_name
        @pgroonga_table_name ||= ActiveRecord::Base.connection.select_value("select pgroonga.table_name('#{index_name}')")
      end

      # scope # => [:issues, :news, :documents, :changesets, :wiki_pages, :messages, :projects]
      def filter_condition(user, project_ids, scope, attachments)
        conditions = []
        attachments_conditions = attachments_conditions(attachments)
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
            target_ids = Project.allowed_to(user, :view_issue).pluck(:id)
            conditions << %Q[(original_type == "Issue" && is_private == false && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            # visible_project_ids[:issue_private] = Project.allowed_to(user, :view_private_issue)
            target_ids = Project.allowed_to(user, :view_notes).pluck(:id)
            conditions << %Q[(original_type == "Journal" && is_private == false && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            target_ids = Project.allowed_to(user, :view_private_notes).pluck(:id)
            conditions << %Q[(original_type == "Journal" && is_private == true && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
            target_ids = CustomField.visible(user).pluck(:id)
            conditions << %Q[(original_type == "CustomValue" && in_values(custom_field_id, #{target_ids.join(',')}))] if target_ids.present?
          when "wiki_pages"
            target_ids = Project.allowed_to(user, :view_wiki_pages).pluck(:id)
            conditions << %Q[(in_values(original_type, "WikiPage", "WikiContent") && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
          else
            target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
            conditions << %Q[(original_type == "#{s.classify}" && in_values(project_id, #{target_ids.join(',')}))] if target_ids.present?
          end
        end
        %Q[pgroonga_tuple_is_alive(ctid) && (#{conditions.join(' || ')})]
      end

      # TODO Attachmentはコンテナごとに条件が必要。コンテナを見ることができたら検索可能にする
      def attachments_conditions(attachments)
        if attachments == "only" || attachments != "0"
          []
        else
          []
        end
      end
    end
  end
end
