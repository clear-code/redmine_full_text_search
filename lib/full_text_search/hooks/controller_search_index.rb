module FullTextSearch
  module Hooks
    module ControllerSearchIndex
      def index
        @full_text_search_order_target = params[:order_target].presence || "score"
        @full_text_search_order_type = params[:order_type].presence || "desc"
        params[:order_target] = @full_text_search_order_target
        params[:order_type] = @full_text_search_order_type
        super
      end
    end
  end
end
