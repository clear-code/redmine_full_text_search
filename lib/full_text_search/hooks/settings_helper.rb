module FullTextSearch
  module Hooks
    module SettingsHelper
      def display_score?
        Setting.plugin_full_text_search.display_score?
      end
    end
  end
end
