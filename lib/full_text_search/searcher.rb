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
        "offset" => (@request.offset || 0).to_s,
        "limit" => (@request.limit || 10).to_s,
      }
      add_dynamic_column(arguments,
                         "highlighted_title",
                         "stage" => "output",
                         "type" => "ShortText",
                         "flags" => "COLUMN_SCALAR",
                         "value" => "highlight_html(title)")
      add_dynamic_column(arguments,
                         "content_snippets",
                         "stage" => "output",
                         "type" => "ShortText",
                         "flags" => "COLUMN_VECTOR",
                         "value" => "snippet_html(content)")
      add_drilldown(arguments,
                    "source_type",
                    "keys" => "source_type_id",
                    "limit" => "-1")
      add_drilldown(arguments,
                    "tag",
                    "keys" => "tag_ids",
                    "limit" => "-1",
                    "sort_keys" => "-_nsubrecs")
      if arguments["query"].blank?
        arguments["limit"] = "0"
      end
      arguments["filter"] = "false" unless arguments["filter"]
      command = Groonga::Command::Select.new("select", arguments)
      response = Target.select(command)
      raise Groonga::Client::Error, response.message unless response.success?
      ResultSet.new(response)
    end

    private
    def match_columns
      if @request.titles_only?
        ["title"]
      else
        ["title * 100", "scorer_tf_at_most(content, 5)"]
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
      status_ids = IssueStatus.where(is_closed: false).pluck(:id)
      tag_ids = status_ids.collect do |status_id|
        Tag.issue_status(status_id).id
      end
      "in_values(tag_ids, #{tag_ids.join(', ')})"
    end

    def filter
      project_ids = target_project_ids
      return nil if project_ids.empty?

      user = @request.user
      sub_conditions = []
      @request.target_search_types.each do |search_type|
        case search_type
        when "projects"
          sub_conditions << [
            "&&",
            "source_type_id == #{Type.project.id}",
            "in_values(project_id, #{project_ids.join(', ')})",
          ]
          if @search_attachment
            sub_conditions << [
              "&&",
              "source_type_id == #{Type.attachment.id}",
              "container_type_id == #{Type.project.id}",
              "in_values(project_id, #{project_ids.join(', ')})",
            ]
          end
          target_ids = CustomField.visible(user).pluck(:id)
          if target_ids.present?
            sub_conditions << [
              "&&",
              "source_type_id == #{Type.custom_value.id}",
              "in_values(custom_field_id, #{target_ids.join(', ')})",
            ]
          end
        when "issues"
          target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
          target_ids &= project_ids
          if target_ids.present?
            sub_conditions << [
              "&&",
              "source_type_id == #{Type.issue.id}",
              "is_private == false",
              "in_values(project_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
            if @request.attachments?
              sub_conditions << [
                "&&",
                "source_type_id == #{Type.attachment.id}",
                "container_type_id == #{Type.issue.id}",
                "is_private == false",
                "in_values(project_id, #{project_ids.join(', ')})",
                open_issues_condition,
              ]
            end
            sub_conditions << [
              "&&",
              "source_type_id == #{Type.journal.id}",
              "is_private == false",
              "in_values(project_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
          end
          target_ids = Project.allowed_to(user, :view_private_notes).pluck(:id)
          target_ids &= project_ids
          if target_ids.present?
            sub_conditions << [
              "&&",
              "source_type_id == #{Type.journal.id}",
              "is_private == true",
              "in_values(project_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
          end
          target_ids = CustomField.visible(user).pluck(:id)
          if target_ids.present?
            sub_conditions << [
              "&&",
              "source_type_id == #{Type.custom_value.id}",
              "is_private == false",
              "in_values(project_id, #{project_ids.join(', ')})",
              "in_values(custom_field_id, #{target_ids.join(', ')})",
              open_issues_condition,
            ]
          end
        else
          target_ids =
            Project.allowed_to(user, :"view_#{search_type}").pluck(:id)
          target_ids &= project_ids
          if target_ids.present?
            type = Type[search_type]
            sub_conditions << [
              "&&",
              "source_type_id == #{type.id}",
              "in_values(project_id, #{target_ids.join(', ')})",
            ]
            if @request.attachments?
              sub_conditions << [
                "&&",
                "source_type_id == #{Type.attachment.id}",
                "container_type_id == #{type.id}",
                "in_values(project_id, #{project_ids.join(', ')})",
              ]
            end
          end
        end
      end
      conditions = []
      # TODO: Optimize project_id search
      # conditions << "in_values(project_id, #{project_ids.join(', ')})"
      unless @request.tags.blank?
        tag_conditions = ["&&"]
        @request.tags.each do |tag_id|
          tag_conditions << "in_values(tag_ids, #{Integer(tag_id, 10)})"
        end
        conditions << tag_conditions
      end
      conditions << ["||", *sub_conditions]
      build_condition("&&", conditions)
    end

    def output_columns
      [
        "_score",
        "content_snippets",
        "id",
        "last_modified_at",
        "project_id",
        "source_id",
        "source_type_id",
        "title",
        "highlighted_title",
        "tag_ids",
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
          "#{direction}last_modified_at",
        ]
      else
        # TODO: -_score is useful?
        [
          "#{direction}_score",
          "-last_modified_at",
        ]
      end
    end

    def add_dynamic_column(arguments, label, options)
      options.each do |name, value|
        arguments["columns[#{label}].#{name}"] = value
      end
    end

    def add_drilldown(arguments, label, options)
      options.each do |name, value|
        arguments["drilldowns[#{label}].#{name}"] = value
      end
    end
  end

  class ResultSet
    include Enumerable

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

    def elapsed_time
      @response.elapsed_time
    end

    # @return Array<FullTextSearch::Target>
    def records
      return [] unless @response.success?
      @records ||= @response.records.map do |record|
        # Rails.logger.debug(title: record["title_digest"],
        #                    description: record["description_digest"])
        record["last_modified_at"] += Target.time_offset
        record["highlighted_title"] = record["highlighted_title"].html_safe
        record["content_snippets"] = record["content_snippets"].collect do |snippet|
          snippet.html_safe
        end
        Target.new(record)
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

    def source_drilldown(name)
      targets = [Type[name].id]
      case name
      when "issues"
        targets << Type.journal.id
      end
      @response.drilldowns["source_type"].records.inject(0) do |count, record|
        if targets.include?(record["_key"])
          count + record["_nsubrecs"]
        else
          count
        end
      end
    end

    def tag_drilldown
      @response.drilldowns["tag"].records.collect do |record|
        {
          tag: Tag.find(record["_key"]),
          n_records: record["_nsubrecs"],
        }
      end
    end

    def tag_drilldowns
      grouped_tag_drilldown = tag_drilldown.group_by do |drilldown|
        drilldown[:tag].type_id
      end
      grouped_tag_drilldown.collect do |type_id, drilldown|
        [TagType.find(type_id), drilldown]
      end
    end
  end
end
