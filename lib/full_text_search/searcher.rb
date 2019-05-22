require "groonga/client/response"

module FullTextSearch
  class Searcher
    def initialize(request)
      @request = request
    end

    def search
      arguments = {
        "match_columns" => match_columns.join(" || "),
        "query" => @request.query,
        "query_flags" => "ALLOW_COLUMN|ALLOW_LEADING_NOT|QUERY_NO_SYNTAX_ERROR",
        "filter" => filter,
        "output_columns" => output_columns.join(", "),
        "sort_keys" => sort_keys.join(", "),
        "offset" => @request.offset,
        "limit" => @request.limit,
        "drilldown" => "original_type",
      }
      return SearchResult.new(empty_response) unless arguments["filter"]

      add_dynamic_column(arguments,
                         "title_digest",
                         "stage" => "output",
                         "type" => "ShortText",
                         "flags" => "COLUMN_SCALAR",
                         "value" => title_digest_value)
      add_dynamic_column(arguments,
                         "description_digest",
                         "stage" => "output",
                         "type" => "ShortText",
                         "flags" => "COLUMN_VECTOR",
                         "value" => description_digest_value)
      add_dynamic_column(arguments,
                         "calculated_updated_on",
                         "stage" => "filtered",
                         "type" => "Time",
                         "flags" => "COLUMN_SCALAR",
                         "value" => calculated_updated_on_value)
      command = Groonga::Command::Select.new("select", arguments)
      response = FullTextSearch::SearcherRecord.select(command)
      raise Groonga::Client::Error, response.message unless response.success?
      SearchResult.new(response)
    end

    private
    def title_columns
      [
        "name",
        "identifier",
        "title",
        "subject",
        "filename",
        "short_comments",
      ]
    end

    def description_columns
      [
        "content",
        "description",
        "long_comments",
        "notes",
        "summary",
        "text",
        "value",
      ]
    end

    def match_columns
      if @request.titles_only?
        title_columns
      else
        title_columns.collect {|column| "#{column} * 100"} +
          description_columns.collect {|column| "scorer_tf_at_most(#{column}, 5)"}
      end
    end

    def visible_project_ids
      if @request.user.respond_to?(:visible_project_ids)
        @request.user.visible_project_ids
      else
        Project.visible(@request.user).pluck(:id)
      end
    end

    def target_project_ids
      target_projects = @request.target_projects
      case target_projects
      when Array
        target_projects.map(&:id) & visible_project_ids
      when Project
        [target_projects.id] & visible_project_ids
      else
        visible_project_ids
      end
    end

    def build_condition(operator, conditions)
      conditions = conditions.compact.collect do |condition|
        if condition.is_a?(Array)
          sub_operator, *sub_conditions = condition
          build_condition(sub_operator, sub_conditions)
        else
          condition
        end
      end
      operator = " #{operator} "
      "(#{conditions.join(operator)})"
    end

    def open_issues_condition
      return nil unless @request.open_issues?
      @status_ids ||= IssueStatus.where(is_closed: false).pluck(:id)
      "in_values(status_id, #{@status_ids.join(', ')})"
    end

    def filter
      project_ids = target_project_ids
      return nil if project_ids.empty?

      user = @request.user
      conditions = []
      @request.scope.each do |scope|
        case scope
        when "projects"
          conditions << [
            "&&",
            "original_type == 'Project'",
            "in_values(original_id, #{project_ids.join(', ')})",
          ]
          if @search_attachment
            conditions << [
              "&&",
              "original_type == 'Attachment'",
              "container_type == 'Project'",
              "in_values(project_id, #{project_ids.join(', ')})",
            ]
          end
          target_ids = CustomField.visible(user).pluck(:id)
          if target_ids.present?
            conditions << [
              "&&",
              "original_type == 'CustomValue'",
              "in_values(custom_field_id, #{target_ids.join(', ')})",
            ]
          end
        when "issues"
          target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
          target_ids &= project_ids
          if target_ids.present?
            conditions << [
              "&&",
              'original_type == "Issue"',
              "is_private == false",
              "in_values(project_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
            if @request.attachments?
              conditions << [
                "&&",
                "original_type == 'Attachment'",
                "container_type == 'Issue'",
                "is_private == false",
                "in_values(project_id, #{project_ids.join(', ')})",
                open_issues_condition,
              ]
            end
            conditions << [
              "&&",
              "original_type == 'Journal'",
              "private_notes == false",
              "in_values(project_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
          end
          target_ids = Project.allowed_to(user, :view_private_notes).pluck(:id)
          target_ids &= project_ids
          if target_ids.present?
            conditions << [
              "&&",
              "original_type == 'Journal'",
              "private_notes == true",
              "in_values(project_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
          end
          target_ids = CustomField.visible(user).pluck(:id)
          if target_ids.present?
            conditions << [
              "&&",
              'original_type == "CustomValue"',
              "is_private == false",
              "in_values(project_id, #{project_ids.join(', ')})",
              "in_values(custom_field_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
          end
        else
          target_ids = Project.allowed_to(user, :"view_#{scope}").pluck(:id)
          target_ids &= project_ids
          if target_ids.present?
            conditions << [
              "&&",
              "original_type == '#{scope.classify}'",
              "in_values(project_id, #{target_ids.join(', ')})",
            ]
            if @request.attachments?
              conditions << [
                "&&",
                "original_type == 'Attachment'",
                "container_type == '#{scope.classify}'",
                "in_values(project_id, #{project_ids.join(', ')})",
              ]
            end
          end
        end
      end
      build_condition("||", conditions)
    end

    def output_columns
      [
        "_score",
        "description_digest",
        "filename",
        "id",
        "identifier",
        "original_created_on",
        "original_id",
        "original_type",
        "original_updated_on",
        "project_id",
        "title_digest",
      ]
    end

    def sort_keys
      if @request.order_type == "desc"
        direction = "-"
      else
        direction = ""
      end
      case @request.order_target
      when "date"
        [
          "#{direction}calculated_updated_on",
          "#{direction}original_updated_on",
          "#{direction}original_created_on",
        ]
      else
        # TODO: -_score is useful?
        [
          "#{direction}_score",
          "-calculated_updated_on",
          "-original_updated_on",
          "-original_created_on",
        ]
      end
    end

    def add_dynamic_column(arguments, label, options)
      options.each do |name, value|
        arguments["columns[#{label}].#{name}"] = value
      end
    end

    def title_digest_value
      "highlight_html(#{title_columns.join(' + ')})"
    end

    def description_digest_value
      "snippet_html(#{description_columns.join(' + ')}) || vector_new('')"
    end

    def calculated_updated_on_value
      "max(original_created_on, original_updated_on)"
    end
  end

  class SearchResult
    # [FullTextSearch::SearcherRecord]
    attr_reader :records

    def initialize(response)
      @response = response
    end

    # @return Integer the number of records
    def count
      if @response.success?
        @response.total_count
      else
        0
      end
    end

    def count_by_type
      return {} unless @response.success?
      @response.drilldowns.first.records.inject(Hash.new{|h, k| h[k] = 0 }) do |memo, r|
        key = case r.values[0]
              when "Journal"
                "issues"
              when "WikiContent"
                "wiki_pages"
              else
                r.values[0].tableize
              end
        memo[key] += r.values[1]
        memo
      end
    end

    def records_by_type
      @records_by_type ||= records.group_by(&:original_type)
    end

    # @return [FullTextSearch::SearcherRecord]
    def records
      return [] unless @response.success?
      @records ||= @response.records.map do |record|
        Rails.logger.debug(title: record["title_digest"],
                           description: record["description_digest"])
        FullTextSearch::SearcherRecord.new(record)
      end
    end

    def raw_records
      @response.records
    end

    def each
      records.each do |record|
        yield record
      end
    end
  end
end
