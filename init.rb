Redmine::Plugin.register :full_text_search do
  name 'Full Text Search plugin'
  author 'ClearCode Inc.'
  description 'This plugin provides full text search for Redmine'
  version '1.0.3'
  url 'https://github.com/clear-code/redmine_full_text_search'
  author_url 'https://github.com/clear-code'
  directory __dir__
  settings partial: "settings/full_text_search"
end

Redmine::Search.map do |search|
  search.register :changes
  search.register :files
end

autoload_paths = [
  File.join(__dir__, "app", "jobs"),
  File.join(__dir__, "app", "types"),
]
ActiveSupport::Dependencies.autoload_paths += autoload_paths
if Rails.application.config.eager_load
  Rails.application.config.eager_load_paths += autoload_paths
end

require_relative "config/initializers/chupa_text"

Rails.configuration.to_prepare do
  require_dependency "full_text_search"
  require_dependency "full_text_search/settings"
  require_dependency "full_text_search/tracer"
  require_dependency "full_text_search/resolver"
  require_dependency "full_text_search/text_extractor"
  require_dependency "full_text_search/batch_runner"
  require_dependency "full_text_search/repository_entry"

  require_dependency "full_text_search/scm_adapter_cat_io"
  require_dependency "full_text_search/scm_adapter_all_file_entries"

  require_dependency "full_text_search/mapper"

  # Order by priority on synchronize
  require_dependency "full_text_search/journal_mapper"
  require_dependency "full_text_search/issue_mapper"
  require_dependency "full_text_search/wiki_page_mapper"
  require_dependency "full_text_search/custom_value_mapper"
  require_dependency "full_text_search/project_mapper"
  require_dependency "full_text_search/news_mapper"
  require_dependency "full_text_search/document_mapper"
  require_dependency "full_text_search/message_mapper"
  require_dependency "full_text_search/attachment_mapper"
  require_dependency "full_text_search/changeset_mapper"
  require_dependency "full_text_search/change_mapper"

  require_dependency "full_text_search/hooks/search_index_options_content_bottom_hook"
  require_dependency "full_text_search/hooks/issues_show_description_bottom_hook"
  require_dependency "full_text_search/hooks/similar_issues_helper"
  require_dependency "full_text_search/searcher"
  require_dependency "full_text_search/similar_searcher"

  class << Setting
    prepend FullTextSearch::SettingsObjectize
  end

  FullTextSearch.resolver.each do |redmine_class, mapper_class|
    mapper_class.attach(redmine_class)
  end
  Issue.include(FullTextSearch::SimilarSearcher::Model)
  Journal.include(FullTextSearch::SimilarSearcher::Model)
  SearchController.helper(FullTextSearch::Hooks::SearchHelper)
  SearchController.prepend(FullTextSearch::Hooks::ControllerSearchIndex)
  IssuesController.helper(FullTextSearch::Hooks::SimilarIssuesHelper)

  FullTextSearch::Tag
  FullTextSearch::TagType
  FullTextSearch::Type
end
