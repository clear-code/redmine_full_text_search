module FullTextSearch
  module Hooks
    module ControllerSearchIndex
      def index
        @search_request = Request.new(query_params)
        @search_request.user = User.current
        @search_request.project = @project

        page = (params[:page].presence || 1).to_i
        case params[:format]
        when 'xml', 'json'
          offset, limit = api_offset_and_limit
        else
          limit = Setting.search_results_per_page.to_i
          limit = 10 if limit == 0
          offset = (page - 1) * limit
        end
        @search_request.offset = offset
        @search_request.limit = limit

        # quick jump to an issue
        if (m = @search_request.query.match(/^#?(\d+)$/)) &&
           (issue = Issue.visible.find_by_id(m[1].to_i))
          redirect_to issue_path(issue)
          return
        end

        ActiveSupport::Notifications.subscribe("groonga.search") do |*args|
          @groonga_search_event = ActiveSupport::Notifications::Event.new(*args)
        end
        searcher = Searcher.new(@search_request)
        @result_set = searcher.search
        @result_pages = Redmine::Pagination::Paginator.new(@result_set.count,
                                                           @search_request.limit,
                                                           params["page"])

        respond_to do |format|
          format.html { render layout: false if request.xhr? }
          format.api { render layout: false }
        end
      end

      private
      def query_params
        permitted_names = [
          :q,
          :scope,
          :all_words,
          :titles_only,
          :attachments,
          :open_issues,
          :format,
          :order_target,
          :order_type,
          :options,
        ]
        Redmine::Search.available_search_types.each do |type|
          permitted_names << type.to_sym
        end
        params.permit(*permitted_names,
                      tags: [])
      end
    end
  end
end
