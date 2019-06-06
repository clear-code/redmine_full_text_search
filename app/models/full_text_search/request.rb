module FullTextSearch
  class Request
    include ActiveModel::Model
    extend ActiveModel::Naming

    attr_accessor :search_id

    attr_accessor :user
    attr_accessor :project

    attr_writer :q
    attr_accessor :scope
    attr_writer :all_words
    attr_writer :titles_only
    attr_writer :attachments
    attr_writer :open_issues
    attr_accessor :offset
    attr_accessor :limit
    attr_accessor :format
    attr_writer :order_target
    attr_writer :order_type
    attr_writer :options
    attr_accessor :tags

    Redmine::Search.available_search_types.each do |type|
      attr_accessor type
    end

    def initialize(*args, &block)
      Redmine::Search.available_search_types.each do |type|
        __send__("#{type}=", 1)
      end
      super
      @search_id ||= Time.zone.now.to_f.to_s
    end

    def to_params(custom_params={})
      params = {
        "search_id" => search_id,
        "q" => q,
        "scope" => scope,
        "all_words" => all_words,
        "titles_only" => titles_only,
        "attachments" => attachments,
        "open_issues" => open_issues,
        "offset" => offset,
        "limit" => limit,
        "order_target" => custom_params[:order_target] || order_target,
        "order_type" => custom_params[:order_type] || order_type,
        "options" => options,
      }
      to_params_types(params, custom_params)
      to_params_order_type(params, custom_params)
      to_params_tags(params, custom_params)
      params
    end

    def target_projects
      case scope
      when "all"
        nil
      when "my_projects"
        user.projects
      when "subprojects"
        @project ? (@project.self_and_descendants.active.to_a) : nil
      else
        @project
      end
    end

    def q
      (@q || "").strip
    end
    alias_method :query, :q

    def all_words
      @all_words.presence || "1"
    end

    def all_words?
      all_words == "1"
    end

    def titles_only
      @titles_only.presence || "0"
    end

    def titles_only?
      titles_only == "1"
    end

    def attachments
      @attachments.presence || "1"
    end

    def attachments?
      case attachments
      when "1", "only"
        true
      else
        false
      end
    end

    def attachments_only?
      attachments == "only"
    end

    def open_issues
      @open_issues.presence || "0"
    end

    def open_issues?
      open_issues == "1"
    end

    def order_target
      @order_target.presence || "score"
    end

    def order_type
      @order_type.presence || "desc"
    end

    def options
      @options.presence || "0"
    end

    def search_types
      @search_types ||= compute_search_types
    end

    def target_search_types
      @target_search_types ||= compute_target_search_types
    end

    def target?(type)
      case type
      when :all
        search_types == target_search_types
      else
        target_search_types.include?(type) and
          (not target?(:all))
      end
    end

    def tag_drilldown?(tag_type_id)
      each_tag.any? do |tag|
        tag.type_id == tag_type_id
      end
    end

    private
    def compute_search_types
      types = Redmine::Search.available_search_types.dup
      projects = target_projects
      if projects.is_a?(Project)
        types.delete("projects")
        u = user
        types = types.select do |type|
          case type
          when "changes"
            allow_type = "changesets"
          when "journals"
            allow_type = "issues"
          else
            allow_type = type
          end
          u.allowed_to?(:"view_#{allow_type}", projects)
        end
      end
      types
    end

    def compute_target_search_types
      target_types = search_types.select do |type|
        __send__(type) == "1"
      end
      if target_types.empty?
        search_types
      else
        target_types
      end
    end

    def to_params_types(params, custom_params)
      types = custom_params[:types]
      case types
      when :all
        search_types.each do |type|
          params[type] = "1"
        end
      when nil
        target_search_types.each do |type|
          params[type] = "1"
        end
      else
        types.each do |type|
          params[type] = "1"
        end
      end
    end

    def to_params_order_type(params, custom_params)
      if custom_params[:invert_order_type]
        params["order_type"] =
          (params["order_type"] == "desc" ? "asc" : "desc")
      end
    end

    def to_params_tags(params, custom_params)
      custom_tags = custom_params[:tags] || []
      deselect_tag_type = custom_params[:deselect_tag_type]
      tags = []
      each_tag do |tag|
        tag_type_id = tag.type_id
        next if tag_type_id == deselect_tag_type
        next if custom_tags.any? {|custom_tag| custom_tag.type_id == tag_type_id}
        tags << tag
      end
      params["tags"] = (tags + custom_tags).collect(&:id)
    end

    def each_tag
      return to_enum(__method__) unless block_given?
      (tags || []).each do |tag_id|
        yield(Tag.find(Integer(tag_id, 10)))
      end
    end
  end
end
