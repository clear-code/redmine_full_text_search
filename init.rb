require_dependency "full_text_search/hooks/search_index_options_content_bottom_hook"
require "full_text_search/searcher"

Redmine::Plugin.register :full_text_search do
  name 'Full Text Search plugin'
  author 'Kenji Okimoto'
  description 'This plugin provides full text search for Redmine'
  version '0.4.0'
  url 'https://github.com/okkez/redmine_full_text_search'
  author_url 'https://github.com/okkez/redmine_full_text_search'
  settings default: { display_score: "0" }, partial: "settings/full_text_search"
end

Rails.configuration.to_prepare do
  case
  when Redmine::Database.postgresql?
    require "full_text_search/pgroonga"
    FullTextSearch::SearcherRecord.prepend(FullTextSearch::PGroonga)
  when Redmine::Database.mysql?
    require "full_text_search/mroonga"
    %w[projects news issues documents changesets messages wiki_pages].each do |name|
      name.classify.constantize.prepend(FullTextSearch::Mroonga)
      name.classify.constantize.include(FullTextSearch::Mroonga)
    end
    %w[attachments custom_values journals wiki_contents].each do |name|
      name.classify.constantize.include(FullTextSearch::Mroonga)
    end
  else
    # Do nothing
  end
  SearchHelper.prepend(FullTextSearch::Hooks::SearchHelper)
  SearchController.prepend(FullTextSearch::Hooks::ControllerSearchIndex)
  Redmine::Search::Fetcher.prepend(FullTextSearch::Fetcher)
end
