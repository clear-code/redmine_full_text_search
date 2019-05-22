module FullTextSearch
  class SearchRequest
    include ActiveModel::Model
    extend ActiveModel::Naming

    attr_accessor :user
    attr_accessor :project

    attr_writer :q
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

    Redmine::Search.available_search_types.each do |type|
      attr_accessor type
    end

    def initialize(*args, &block)
      Redmine::Search.available_search_types.each do |type|
        __send__("#{type}=", 1)
      end
      super
    end

    def target_projects
      case @scope
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
      @all_words.nil? ? true : @all_words.present?
    end
    alias_method :all_words?, :all_words

    def titles_only
      @titles_only.nil? ? false : @titles_only.present?
    end
    alias_method :titles_only?, :titles_only

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

    def open_issues?
      @open_issues.nil? ? false : @open_issues.present?
    end

    def order_target
      @order_target.presence || "score"
    end

    def order_type
      @order_type.presence || "desc"
    end

    def options
      @options.presence || "1"
    end

    def search_types
      @search_types ||= compute_search_types
    end

    def scope
      @scope ||= compute_target_search_types
    end

    private
    def compute_search_types
      types = Redmine::Search.available_search_types.dup
      _projects = projects
      if _projects.is_a?(Project)
        types.delete("projects")
        u = user
        types = types.select do |type|
          u.allowed_to?(:"view_#{type}", _projects)
        end
      end
      types
    end

    def compute_target_search_types
      target_types = search_types.select do |type|
        __send__(type)
      end
      if target_types.empty?
        search_types
      else
        target_types
      end
    end
  end
end
