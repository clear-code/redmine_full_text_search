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

        searcher = Searcher.new(@search_request)
        @result_set = searcher.search
        context = @search_request.to_params
        context = context.merge("user_id" => @search_request.user.id,
                                "project_id" => @search_request.project.id,
                                "n_hits" => @result_set.count,
                                "elapsed_time" => @result_set.elapsed_time,
                                "timestamp" => Time.zone.now.iso8601)
        log = "[full-text-search][search] #{context.to_json}"
        Rails.logger.info(log)
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
          :search_id,
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
