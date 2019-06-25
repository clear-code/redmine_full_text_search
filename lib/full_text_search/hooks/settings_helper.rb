module FullTextSearch
  module Hooks
    module SettingsHelper
      def fts_display_score?
        Setting.plugin_full_text_search.display_score?
      end

      def fts_display_similar_issues?
        Setting.plugin_full_text_search.display_similar_issues?
      end
    end
  end
end
