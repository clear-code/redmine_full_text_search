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
                    "container_type",
                    "keys" => "container_type_id",
                    "limit" => "-1")
      add_drilldown(arguments,
                    "tag",
                    "keys" => "tag_ids",
                    "limit" => "-1",
                    "sort_keys" => "-_nsubrecs")
      unless @request.have_condition?
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

    def filter
      project_ids = target_project_ids
      return nil if project_ids.empty?

      user = @request.user
      conditions = []
      conditions << "in_values(project_id, #{project_ids.join(', ')})"
      unless @request.tags.blank?
        tag_ids = @request.tags.collect do |tag_id|
          Integer(tag_id, 10)
        end
        if Target.highlight_keyword_extraction_is_broken?
          conditions << "&&"
          conditions << "query('tag_ids', '#{tag_ids.join(' ')}')"
        else
          tag_ids.each do |tag_id|
            conditions << "&&"
            conditions << "tag_ids @ #{tag_id}"
          end
        end
      end

      if @request.open_issues?
        closed_status_ids = IssueStatus.where(is_closed: true).pluck(:id)
        closed_status_ids.each do |closed_status_id|
          tag_id = Tag.issue_status(closed_status_id).id
          conditions << "&!"
          if Target.highlight_keyword_extraction_is_broken?
            conditions << "query('tag_ids', '#{tag_id}')"
          else
            conditions << "tag_ids @ #{tag_id}"
          end
        end
      end

      # TODO: Support private notes again
      # Project.allowed_to(user, :view_private_notes).pluck(:id)
      conditions << "&!"
      conditions << "is_private == true"

      unless @request.attachments?
        conditions << "&!"
        conditions << "source_type_id == #{Type.attachment.id}"
      end

      not_target_custom_field_ids =
        CustomField
          .where(searchable: true)
          .where.not(id: CustomField.visible(user))
          .pluck(:id)
      if not_target_custom_field_ids.present?
        conditions << "&!"
        conditions <<
          "in_values(custom_field_id, " +
          "#{not_target_custom_field_ids.join(', ')})"
      end

      not_search_types =
        Redmine::Search.available_search_types - @request.target_search_types
      not_search_types.each do |not_search_type|
        not_search_type_id = Type[not_search_type].id
        conditions << "&!"
        conditions << "source_type_id == #{not_search_type_id}"
        conditions << "&!"
        conditions << "container_type_id == #{not_search_type_id}"
      end

      @request.target_search_types.each do |search_type|
        invisible_project_ids =
          project_ids - Project.allowed_to(user, :view_issues).pluck(:id)
        next unless invisible_project_ids.present?

        source_type_id = Type[search_type].id
        conditions << "&!"
        conditions << "("
        conditions <<
          "in_values(project_id, #{invisible_project_ids.join(', ')})"
        conditions << "&&"
        conditions << "("
        conditions << "source_type_id == #{source_type_id}"
        conditions << "||"
        conditions << "container_type_id == #{source_type_id}"
        conditions << ")"
        conditions << ")"
      end

      conditions.join(" ")
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
      target_id  = Type[name].id
      count = 0
      @response.drilldowns["source_type"].records.each do |record|
        count += record["_nsubrecs"] if record["_key"] == target_id
      end
      @response.drilldowns["container_type"].records.each do |record|
        count += record["_nsubrecs"] if record["_key"] == target_id
      end
      count
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
