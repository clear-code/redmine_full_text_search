module FullTextSearch
  module Hooks
    module SettingsHelper
      def fts_display_score?
        Setting.plugin_full_text_search.display_score?
      end

      def fts_display_similar_issues?
        Setting.plugin_full_text_search.display_similar_issues?
      end

      def fts_enable_tracking?
        Setting.plugin_full_text_search.enable_tracking?
      end
    end
  end
end
