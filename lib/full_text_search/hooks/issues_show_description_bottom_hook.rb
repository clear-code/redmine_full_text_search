module FullTextSearch
  module Hooks
    class IssuesShowDescriptionBottomHook < Redmine::Hook::ViewListener
      include Redmine::I18n

      render_on(:view_issues_show_description_bottom,
                partial: "issues/full_text_search/view_issues_show_description_bottom")
    end
  end
end
