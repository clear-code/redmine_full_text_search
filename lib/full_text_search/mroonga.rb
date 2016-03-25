module FullTextSearch
  module Mroonga
    def self.prepended(base)
      base.extend(ClassMethods)
      base.class_eval do
        has_one("fts_#{table_name.singularize}".to_sym,
                dependent: :destroy,
                class_name: "FullTextSearch::Mroonga::#{base.name}")
      end
    end

    module ClassMethods
      # Overwrite ActsAsSearchable
      def fetch_ranks_and_ids(scope, limit)
        if self == ::WikiPage
          scope.reorder("score1 DESC, score2 DESC").distinct.limit(limit).map do |record|
            [record.score1 * 100 + record.score2, record.id]
          end
        else
          scope.reorder("score DESC").distinct.limit(limit).map do |record|
            [record.score, record.id]
          end
        end
      end

      def search_result_ranks_and_ids(tokens, user=::User.current, projects=nil, options={})
        tokens = [] << tokens unless tokens.is_a?(Array)
        projects = [] << projects if projects.is_a?(::Project)

        columns = searchable_options[:columns]
        columns = columns[0..0] if options[:titles_only]

        r = []
        queries = 0

        unless options[:attachments] == 'only'
          if self == ::WikiPage
            columns1 = [columns.first]
            columns2 = [columns.last]
            s1 = ActiveRecord::Base.send(:sanitize_sql_array,
                                         search_tokens_condition(columns1, tokens, options[:all_words]))
            s2 = ActiveRecord::Base.send(:sanitize_sql_array,
                                         search_tokens_condition(columns2, tokens, options[:all_words]))
            c1 = search_tokens_condition(columns1, tokens, options[:all_words])
            c2 = search_tokens_condition(columns2, tokens, options[:all_words])
            c, t = c1.zip(c2).to_a
            r = fetch_ranks_and_ids(
              search_scope(user, projects, options).
              select(:id, "#{s1} AS score1", "#{s2} AS score2").
              where([c.join(" OR "), *t]),
              options[:limit]
            )
          else
            s = ActiveRecord::Base.send(:sanitize_sql_array,
                                        search_tokens_condition(columns, tokens, options[:all_words]))
            r = fetch_ranks_and_ids(
              search_scope(user, projects, options).
              select(:id, "#{s} AS score").
              where(search_tokens_condition(columns, tokens, options[:all_words])),
              options[:limit]
            )
          end
          queries += 1

          if !options[:titles_only] && searchable_options[:search_custom_fields]
            searchable_custom_fields = ::CustomField.where(:type => "#{self.name}CustomField", :searchable => true).to_a

            if searchable_custom_fields.any?
              fields_by_visibility = searchable_custom_fields.group_by {|field|
                field.visibility_by_project_condition(searchable_options[:project_key], user, "#{CustomValue.table_name}.custom_field_id")
              }
              clauses = []
              fields_by_visibility.each do |visibility, fields|
                clauses << "(#{::CustomValue.table_name}.custom_field_id IN (#{fields.map(&:id).join(',')}) AND (#{visibility}))"
              end
              visibility = clauses.join(' OR ')
              s = ActiveRecord::Base.send(:sanitize_sql_array,
                                          search_tokens_condition(columns, tokens, options[:all_words]))

              r |= fetch_ranks_and_ids(
                search_scope(user, projects, options).
                select(:id, "#{s} AS score").
                joins(:custom_values).
                where(visibility).
                where(search_tokens_condition(["#{::CustomValue.table_name}.value"], tokens, options[:all_words])),
                options[:limit]
              )
              queries += 1
            end
          end

          if !options[:titles_only] && searchable_options[:search_journals]
            s = ActiveRecord::Base.send(:sanitize_sql_array,
                                        search_tokens_condition(columns, tokens, options[:all_words]))
            r |= fetch_ranks_and_ids(
              search_scope(user, projects, options).
              select(:id, "#{s} AS score").
              joins(:journals).
              where("#{::Journal.table_name}.private_notes = ? OR (#{::Project.allowed_to_condition(user, :view_private_notes)})", false).
              where(search_tokens_condition(["#{::Journal.table_name}.notes"], tokens, options[:all_words])),
              options[:limit]
            )
            queries += 1
          end
        end

        if searchable_options[:search_attachments] && (options[:titles_only] ? options[:attachments] == 'only' : options[:attachments] != '0')
          s = ActiveRecord::Base.send(:sanitize_sql_array,
                                      search_tokens_condition(columns, tokens, options[:all_words]))
          r |= fetch_ranks_and_ids(
            search_scope(user, projects, options).
            select(:id, "#{s} AS score").
            joins(:attachments).
            where(search_tokens_condition(["#{::Attachment.table_name}.filename", "#{::Attachment.table_name}.description"], tokens, options[:all_words])),
            options[:limit]
          )
          queries += 1
        end

        if queries > 1
          r = r.sort_by{|score, id| -score }
          if options[:limit] && r.size > options[:limit]
            r = r[0, options[:limit]]
          end
        end

        r
      end

      def search_tokens_condition(columns, tokens, all_words)
        token_clauses = "MATCH(#{columns.join(",")})"
        pragma = all_words ? "*D+" : "*DOR"
        sql = %Q!#{token_clauses} AGAINST (? IN BOOLEAN MODE)!
        [sql, "#{pragma} #{tokens.join(" ")}"]
      end
    end
  end
end
