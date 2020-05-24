module FullTextSearch
  module Hooks
    module SearchHelper
      include FullTextSearch::Hooks::SettingsHelper

      def search_result_entry_url(e, i)
        if fts_enable_tracking?
          search_parameters = {
            "search_id" => @search_request.search_id,
            "search_n" => i + @search_request.offset,
          }
        else
          search_parameters = {}
        end
        e.event_url.merge(search_parameters)
      end
    end
  end
end
