Redmine::Plugin.register :full_text_search do
  name 'Full Text Search plugin'
  author 'Kenji Okimoto'
  description 'This plugin provides full text search for Redmine'
  version '0.7.2'
  url 'https://github.com/clear-code/redmine_full_text_search'
  author_url 'https://github.com/okkez'
  directory __dir__
  settings default: { display_score: "0" }, partial: "settings/full_text_search"
end

Rails.configuration.to_prepare do
  require_dependency "full_text_search"
  require_dependency "full_text_search/hooks/search_index_options_content_bottom_hook"
  require_dependency "full_text_search/hooks/issues_show_description_bottom_hook"
  require_dependency "full_text_search/hooks/similar_issues_helper"
  require_dependency "full_text_search/searcher"

  case
  when Redmine::Database.postgresql?
    require_dependency "full_text_search/pgroonga"
    FullTextSearch::SearcherRecord.prepend(FullTextSearch::PGroonga)
  when Redmine::Database.mysql?
    require_dependency "full_text_search/mroonga"
    FullTextSearch::SearcherRecord.prepend(FullTextSearch::Mroonga)
  else
    # Do nothing
  end
  FullTextSearch.target_classes.each do |klass|
    klass.include(FullTextSearch::Model)
  end
  Issue.include(FullTextSearch::SimilarSearcher::Model)
  Journal.include(FullTextSearch::SimilarSearcher::Model)
  SearchController.helper(FullTextSearch::Hooks::SearchHelper)
  SearchController.prepend(FullTextSearch::Hooks::ControllerSearchIndex)
  IssuesController.helper(FullTextSearch::Hooks::SimilarIssuesHelper)
end
