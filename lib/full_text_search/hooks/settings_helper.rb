module FullTextSearch
  module Hooks
    module SettingsHelper
      def fts_display_score?
        Setting.plugin_full_text_search.display_score?
      end

      def fts_display_similar_issues?
        Setting.plugin_full_text_search.display_similar_issues?
      end

      def fts_add_search_related_parameters_in_url?
        Setting.plugin_full_text_search.add_search_related_parameters_in_url?
      end
    end
  end
end
