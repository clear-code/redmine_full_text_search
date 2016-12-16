module FullTextSearch
  module Hooks
    module ControllerSearchIndex
      def index
        @full_text_search_order_target = params[:order_target].presence || "score"
        @full_text_search_order_type = params[:order_type].presence || "desc"
        super
      end
    end
  end
end
