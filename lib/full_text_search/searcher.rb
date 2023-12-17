require "groonga/client/response"

module FullTextSearch
  class Searcher
    def initialize(request)
      @request = request
    end

    def search
      arguments = {
        "match_columns" => match_columns.join(" || "),
        "query" => query,
        "query_flags" => "ALLOW_COLUMN|ALLOW_LEADING_NOT|QUERY_NO_SYNTAX_ERROR",
        "filter" => filter,
        "output_columns" => "_id",
        "limit" => "0",
      }
      add_drilldown(arguments,
                    "",
                    "source_type",
                    "keys" => "source_type_id",
                    "limit" => "-1")
      add_drilldown(arguments,
                    "",
                    "container_type",
                    "keys" => "container_type_id",
                    "limit" => "-1")
      not_search_type_conditions = collect_not_search_type_conditions
      if not_search_type_conditions.empty?
        prefix = ""
      else
        if Target.use_slices?
          prefix = "slices[type_filtered]."
          arguments["#{prefix}filter"] =
            (["all_records()"] + not_search_type_conditions).join(" &! ")
        else
          prefix = ""
          if arguments["filter"]
            arguments["filter"] =
              ([arguments["filter"]] + not_search_type_conditions).join(" &! ")
          end
        end
      end
      add_dynamic_column(arguments,
                         prefix,
                         "highlighted_title",
                         "stage" => "output",
                         "type" => "ShortText",
                         "flags" => "COLUMN_SCALAR",
                         "value" => "highlight_html(title)")
      add_dynamic_column(arguments,
                         prefix,
                         "content_snippets",
                         "stage" => "output",
                         "type" => "ShortText",
                         "flags" => "COLUMN_VECTOR",
                         "value" => "snippet_html(content)")
      add_drilldown(arguments,
                    prefix,
                    "tag",
                    "keys" => "tag_ids",
                    "limit" => "-1",
                    "sort_keys" => "-_nsubrecs")
      arguments["#{prefix}output_columns"] = output_columns.join(", ")
      arguments["#{prefix}sort_keys"] = sort_keys.join(", ")
      arguments["#{prefix}offset"] = (@request.offset || 0).to_s
      if @request.have_condition?
        limit = (@request.limit || 10).to_s
      else
        limit = "0"
      end
      arguments["#{prefix}limit"] = limit
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

    def query
      return nil if @request.query.blank?
      query = ""
      conditions = []
      begin
        tag_ids = Tag
                    .where(type_id: TagType.identifier.id)
                    .full_text_search(:name, @request.query)
                    .pluck(:id)
        tag_ids.each do |tag_id|
          conditions << "(tag_ids:@#{tag_id})"
        end
      rescue ActiveRecord::StatementInvalid
        # Ignore syntax error for Groonga's query syntax
      end
      conditions << "(#{@request.query})"
      conditions.join(" OR ")
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
      project_ids = @request.target_project_ids
      return nil if project_ids.empty?

      user = @request.user
      conditions = []
      conditions << "in_values(project_id, #{project_ids.join(', ')})"
      if @request.choose_one_project?
        project_type_id = Type.project.id
        conditions << "&!"
        conditions << "source_type_id == #{project_type_id}"
      end
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

      @request.target_search_types.each do |search_type|
        invisible_project_ids =
          project_ids - @request.viewable_project_ids(search_type)
        next unless invisible_project_ids.present?

        source_type_id = Type[search_type].id
        sub_conditions = []
        sub_conditions << "("
        sub_conditions <<
          "in_values(project_id, #{invisible_project_ids.join(', ')})"
        sub_conditions << "&&"
        sub_conditions << "("
        sub_conditions << "source_type_id == #{source_type_id}"
        sub_conditions << "||"
        sub_conditions << "container_type_id == #{source_type_id}"
        sub_conditions << ")"
        sub_conditions << ")"
        conditions << "&!"
        conditions << sub_conditions.join(" ")
      end

      conditions.join(" ")
    end

    def collect_not_search_type_conditions
      conditions = []

      not_search_types = @request.not_search_types
      if @request.choose_one_project?
        not_search_types -= ["projects"]
      end
      not_search_types.each do |not_search_type|
        not_search_type_id = Type[not_search_type].id
        conditions << "source_type_id == #{not_search_type_id}"
        conditions << "container_type_id == #{not_search_type_id}"
      end

      conditions
    end

    def output_columns
      [
        "_score",
        "content_snippets",
        "id",
        "last_modified_at",
        "registered_at",
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
      when "last_modified_at"
        [
          "#{direction}last_modified_at",
        ]
      when "registered_at"
        [
          "#{direction}registered_at",
        ]
      else
        # TODO: -_score is useful?
        [
          "#{direction}_score",
          "-last_modified_at",
        ]
      end
    end

    def add_dynamic_column(arguments, prefix, label, options)
      options.each do |name, value|
        arguments["#{prefix}columns[#{label}].#{name}"] = value
      end
    end

    def add_drilldown(arguments, prefix, label, options)
      options.each do |name, value|
        arguments["#{prefix}drilldowns[#{label}].#{name}"] = value
      end
    end
  end

  class ResultSet
    include Enumerable

    def initialize(response)
      @response = response
    end

    def n_hits
      if @response.success?
        target.n_hits
      else
        0
      end
    end

    def total_n_hits
      if @response.success?
        @response.n_hits
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
      @records ||= raw_records.map do |record|
        # Rails.logger.debug(title: record["title_digest"],
        #                    description: record["description_digest"])
        record["last_modified_at"] += Target.time_offset
        record["registered_at"] += Target.time_offset
        record["highlighted_title"] = record["highlighted_title"].html_safe
        record["content_snippets"] = record["content_snippets"].collect do |snippet|
          snippet.html_safe
        end
        Target.new(record)
      end
    end

    def raw_records
      target.records
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
      drilldown = []
      target.drilldowns["tag"].records.each do |record|
        tag_id = record["_key"]
        n_records = record["_nsubrecs"]
        begin
          tag = Tag.find(tag_id)
        rescue ActiveRecord::RecordNotFound => error
          related_targets = records.find_all do |target|
            target.tag_ids.include?(tag_id)
          end
          related_target_ids = related_targets.collect(&:id)
          message = "[full-text-search][searcher][drilldown][tag] "
          message << "unknown tag ID exists: #{tag_id}(#{n_records}) "
          message << "related target IDs: #{related_target_ids.inspect}"
          Rails.logger.warn(message)
          next
        end
        begin
          tag.value
        rescue ActiveRecord::RecordNotFound => error
          message = "[full-text-search][searcher][drilldown][tag] "
          message << "orphan tag exists: #{tag_id}(#{n_records}): "
          message << "<#{tag.name}>/<#{tag.type.name}>"
          Rails.logger.warn(message)
          next
        end
        drilldown << {
          tag: tag,
          n_records: n_records,
        }
      end
      drilldown
    end

    def tag_drilldowns
      grouped_tag_drilldown = tag_drilldown.group_by do |drilldown|
        drilldown[:tag].type_id
      end
      grouped_tag_drilldown.collect do |type_id, drilldown|
        [TagType.find(type_id), drilldown]
      end
    end

    private
    def target
      @response.slices["type_filtered"] || @response
    end
  end
end
