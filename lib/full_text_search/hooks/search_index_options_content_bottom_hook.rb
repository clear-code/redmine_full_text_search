module FullTextSearch
  module Hooks
    class SearchIndexOptionsContentBottomHook < Redmine::Hook::ViewListener
      include Redmine::I18n

      render_on(:view_search_index_options_content_bottom,
                partial: "search/full_text_search/view_search_index_options_content_bottom")
    end
  end
end
