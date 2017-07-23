module FullTextSearch
  module Hooks
    module ControllerSearchIndex
      def index
        @full_text_search_order_target = params[:order_target].presence || "score"
        @full_text_search_order_type = params[:order_type].presence || "desc"
        params[:order_target] = @full_text_search_order_target
        params[:order_type] = @full_text_search_order_type

        # Copy from SearchController
        @question = params[:q] || ""
        @question.strip!
        @all_words = params[:all_words] ? params[:all_words].present? : true
        @titles_only = params[:titles_only] ? params[:titles_only].present? : false
        @search_attachments = params[:attachments].presence || '0'
        @open_issues = params[:open_issues] ? params[:open_issues].present? : false

        case params[:format]
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
        else
          @offset = nil
          @limit = Setting.search_results_per_page.to_i
          @limit = 10 if @limit == 0
        end

        # quick jump to an issue
        if (m = @question.match(/^#?(\d+)$/)) && (issue = Issue.visible.find_by_id(m[1].to_i))
          redirect_to issue_path(issue)
          return
        end

        projects_to_search =
          case params[:scope]
          when 'all'
            nil
          when 'my_projects'
            User.current.projects
          when 'subprojects'
            @project ? (@project.self_and_descendants.active.to_a) : nil
          else
            @project
          end

        # :issues, :news, :documents, :changesets, :wiki_pages, :messages, :projects
        @object_types = Redmine::Search.available_search_types.dup
        if projects_to_search.is_a? Project
          # don't search projects
          @object_types.delete('projects')
          # only show what the user is allowed to view
          @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
        end

        @scope = @object_types.select {|t| params[t]}
        @scope = @object_types if @scope.empty?

        options = {
          offset: @offset,
          limit: @limit,
          all_words: @all_words,
          titles_only: @titles_only,
          attachments: @search_attachments,
          open_issues: @open_issues,
          cache: params[:page].present?,
          params: params
        }
        searcher = FullTextSearch::Searcher.new(@question, User.current, @scope, projects_to_search, options)
        @search_result = searcher.search
        @result_pages = Paginator.new @search_result.count, @limit, params['page']

        respond_to do |format|
          format.html { render layout: false if request.xhr? }
          format.api { render layout: false }
        end
      end
    end
  end
end
