module FullTextSearch
  module Hooks
    module SettingsHelper
      def display_score?
        setting = Setting.plugin_full_text_search.presence || {}
        setting["display_score"] == "1"
      end
    end
  end
end
