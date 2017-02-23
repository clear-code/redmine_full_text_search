module FullTextSearch
  module Mroonga
    def self.prepended(base)
      base.extend(ClassMethods)
      base.class_eval do
        has_one("fts_#{table_name.singularize}".to_sym,
                dependent: :destroy,
                class_name: "FullTextSearch::Mroonga::Fts#{base.name}")
      end
    end

    def self.included(base)
      base.class_eval do
        after_save Callbacks
      end
    end

    class Callbacks
      def self.after_save(record)
        fts_class = "FullTextSearch::Mroonga::Fts#{record.class.name}".constantize
        columns = fts_class.columns.map(&:name)
        id_column = columns.detect do |column|
          column.end_with?("_id")
        end
        fts_record = fts_class.find_or_initialize_by(id_column => record.id)
        columns.each do |column|
          if column.end_with?("_id")
            fts_record[column] = record.id
          else
            fts_record[column] = record[column]
          end
        end
        fts_record.save!
      end
    end

    module ClassMethods
      # Overwrite ActsAsSearchable
      def fetch_ranks_and_ids(scope, limit, attachments: false, order_target: "score", order_type: "desc")
        if self == ::WikiPage && !attachments
          scope.
            joins("INNER JOIN fts_wiki_contents ON (wiki_contents.id = fts_wiki_contents.wiki_content_id)").
            reorder("score DESC").distinct.limit(limit).map do |record|
            if order_target == "score"
              [record.score, record.id]
            else
              [record.order_target.to_i, record.id]
            end
          end
        else
          scope.reorder("score DESC").distinct.limit(limit).map do |record|
            if order_target == "score"
              [record.score, record.id]
            else
              [record.order_target.to_i, record.id]
            end
          end
        end
      end

      def search_result_ranks_and_ids(tokens, user=::User.current, projects=nil, options={})
        tokens = [] << tokens unless tokens.is_a?(Array)
        projects = [] << projects if projects.is_a?(::Project)
        params = options[:params]
        target_column_name = "#{table_name}.#{order_column_name}"
        kw = {
          order_type: params[:order_type] || "desc",
          order_target: params[:order_target] || "score",
        }

        columns = searchable_options[:columns]
        columns = columns[0..0] if options[:titles_only]

        r = []
        queries = 0

        unless options[:attachments] == 'only'
          if self == ::WikiPage
            column1 = columns.first
            column2 = columns.last
            s1 = ActiveRecord::Base.send(:sanitize_sql_array,
                                         search_tokens_condition_single(column1, tokens, options[:all_words]))
            s2 = ActiveRecord::Base.send(:sanitize_sql_array,
                                         search_tokens_condition_single(column2, tokens, options[:all_words]))
            c1 = search_tokens_condition_single(column1, tokens, options[:all_words])
            c2 = search_tokens_condition_single(column2, tokens, options[:all_words])
            c, t = c1.zip(c2).to_a
            r = fetch_ranks_and_ids(
              search_scope(user, projects, options).
              select(:id, "#{s1} * 100 + #{s2} AS score, #{target_column_name} AS order_target").
              joins(fts_relation).
              where([c.join(" OR "), *t]),
              options[:limit],
              **kw
            )
          else
            conditions = columns.map do |column|
              search_tokens_condition_single(column, tokens, options[:all_words])
            end
            scores = columns.zip(conditions).map do |column, condition; s|
              s = ActiveRecord::Base.send(:sanitize_sql_array, condition)
              case column
              when "title", "subject"
                "#{s} * 100"
              else
                s
              end
            end
            if columns.size == 1
              ct = conditions.flatten
              c = [ct.first]
              t = [ct.last]
            else
              c, t = conditions.first.zip(*conditions[1..-1]).to_a
              p [2, c, t]
            end
            r = fetch_ranks_and_ids(
              search_scope(user, projects, options).
              select(:id, "#{scores.join(" + ")} AS score, #{target_column_name} AS order_target").
              joins(fts_relation).
              where([c.join(" OR "), *t]),
              options[:limit],
              **kw
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
              condition = search_tokens_condition_single("#{::CustomValue.table_name}.value", tokens, options[:all_words])
              score = ActiveRecord::Base.send(:sanitize_sql_array, condition)

              r |= fetch_ranks_and_ids(
                search_scope(user, projects, options).
                select(:id, "#{score} AS score, #{target_column_name} AS order_target").
                joins(fts_relation).
                joins(:custom_values).
                joins("INNER JOIN fts_custom_values ON (custom_values.id = fts_custom_values.custom_value_id)").
                where(visibility).
                where(condition),
                options[:limit],
                **kw
              )
              queries += 1
            end
          end

          if !options[:titles_only] && searchable_options[:search_journals]
            conditions = columns.map do |column|
              search_tokens_condition_single(column, tokens, options[:all_words])
            end
            scores = columns.zip(conditions).map do |column, _condition; m|
              m = ActiveRecord::Base.send(:sanitize_sql_array, _condition)
              case column
              when "subject"
                "#{m} * 100"
              else
                m
              end
            end
            note_condition = search_tokens_condition_single("#{::Journal.table_name}.notes", tokens, options[:all_words])
            note_score = ActiveRecord::Base.send(:sanitize_sql_array, note_condition)
            conditions << note_condition
            scores << note_score
            c, t = conditions.first.zip(*conditions[1..-1]).to_a
            r |= fetch_ranks_and_ids(
              search_scope(user, projects, options).
              select(:id, "SUM(#{scores.join(" + ")}) AS score, #{target_column_name} AS order_target").
              joins(fts_relation).
              joins(:journals).
              joins("INNER JOIN fts_journals ON (journals.id = fts_journals.journal_id)").
              where("#{::Journal.table_name}.private_notes = ? OR (#{::Project.allowed_to_condition(user, :view_private_notes)})", false).
              where([c.join(" OR "), *t]).
              group(:id),
              options[:limit],
              **kw
            )
            queries += 1
          end
        end

        if searchable_options[:search_attachments] && (options[:titles_only] ? options[:attachments] == 'only' : options[:attachments] != '0')
          conditions = ["#{::Attachment.table_name}.filename", "#{::Attachment.table_name}.description"].map do |column|
            search_tokens_condition_single(column, tokens, options[:all_words])
          end
          scores = conditions.map do |condition|
            ActiveRecord::Base.send(:sanitize_sql_array, condition)
          end
          c, t = conditions.first.zip(*conditions[1..-1]).to_a
          r |= fetch_ranks_and_ids(
            search_scope(user, projects, options).
            select(:id, "#{scores.join(" + ")} AS score, #{target_column_name} AS order_target").
            joins(fts_relation).
            joins(:attachments).
            joins("INNER JOIN fts_attachments ON (attachments.id = fts_attachments.attachment_id)").
            where([c.join(" OR "), *t]),
            options[:limit],
            attachments: true,
            **kw
          )
          queries += 1
        end

        if queries > 1
          sign = params[:order_type] == "desc" ? -1 : 1
          r = r.sort_by {|_score, _id| sign * _score }
          if options[:limit] && r.size > options[:limit]
            r = r[0, options[:limit]]
          end
        end

        r
      end

      def search_tokens_condition(columns, tokens, all_words)
        columns = columns.map do |column|
          if column.include?(".")
            "fts_#{column}"
          else
            "#{fts_table_name}.#{column}"
          end
        end
        token_clauses = "MATCH(#{columns.join(",")})"
        pragma = all_words ? "*D+" : "*DOR"
        sql = %Q!#{token_clauses} AGAINST (? IN BOOLEAN MODE)!
        [sql, "#{pragma} #{tokens.join(" ")}"]
      end

      def search_tokens_condition_single(column, tokens, all_words)
        column = column.include?(".") ? "fts_#{column}" : "#{fts_table_name}.#{column}"
        token_clauses = "MATCH(#{column})"
        pragma = all_words ? "*D+" : "*DOR"
        sql = %Q!#{token_clauses} AGAINST (? IN BOOLEAN MODE)!
        [sql, "#{pragma} #{tokens.join(" ")}"]
      end

      def fts_table_name
        "fts_#{table_name}"
      end

      def fts_relation
        "fts_#{table_name.singularize}".to_sym
      end

      #
      # searchable_options[:date_column] is not enough
      # Because almost all models does not use `acts_as_searchable :data_column` option,
      # and searchable_options[:data] default value is `:created_on`
      #
      def order_column_name
        timestamp_columns = ["created_on", "updated_on", "commited_on"]
        column_names.select{|column_name| timestamp_columns.include?(column_name) }.sort.last || "id"
      end
    end
  end
end
