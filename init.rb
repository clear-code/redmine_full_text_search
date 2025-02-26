Redmine::Plugin.register :full_text_search do
  name 'Full Text Search plugin'
  author 'ClearCode Inc.'
  description 'This plugin provides full text search for Redmine'
  version '2.0.2'
  url 'https://github.com/clear-code/redmine_full_text_search'
  author_url 'https://github.com/clear-code'
  # We can't use __dir__ here because we ensure that plugin directory path is a path in Redmine directory
  # even when we use a symbolic link to place this plugin into redmine/plugins/. If we don't use a symbolic
  # link like the following, we can use __dir__ here:
  #
  #   $ git clone https://github.com/clear-code/redmine_full_text_search.git redmine/plugins/full_text_search
  #
  # But __dir__ doesn't work when we use a symbolic link:
  #
  #   $ git clone https://github.com/clear-code/redmine_full_text_search.git
  #   $ cd redmine/plugins
  #   $ ln -s ../../redmine_full_text_search full_text_search
  #
  # In this case, __dir__ and __FILE__ are the followings:
  #
  #   __dir__: /tmp/redmine_full_text_search
  #   __FILE__: ./full_text_search/init.rb
  #
  # Note that "/tmp/redmine_full_text_search" isn't a path in Redmine's plugin directory (redmine/plugins/).
  # Redmine assumes that this is a path in Redmine's plugin directory. So we need to compute this from
  # __FILE__ not __dir__.
  directory File.dirname(File.absolute_path(__FILE__))
  settings partial: "settings/full_text_search"
end

Redmine::Search.map do |search|
  search.register :changes
end

Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :fts_query_expansion,
            {controller: "fts_query_expansions", action: "index"},
            caption: :"label.full_text_search.menu.query_expansions.plural",
            html: {class: "icon icon-magnifier"}
end

require_relative "config/initializers/chupa_text"

FullTextSearch::Settings
FullTextSearch::Tracer
FullTextSearch::Resolver
FullTextSearch::TextExtractor
FullTextSearch::MarkupParser
FullTextSearch::BatchRunner
FullTextSearch::RepositoryEntry

FullTextSearch::ScmAdapterCatIo
FullTextSearch::ScmAdapterAllFileEntries

# Order by priority on synchronize
FullTextSearch::JournalMapper
FullTextSearch::IssueMapper
FullTextSearch::WikiPageMapper
FullTextSearch::CustomValueMapper
FullTextSearch::ProjectMapper
FullTextSearch::NewsMapper
FullTextSearch::DocumentMapper
FullTextSearch::MessageMapper
FullTextSearch::AttachmentMapper
FullTextSearch::ChangesetMapper
FullTextSearch::ChangeMapper

FullTextSearch::Hooks::SearchIndexOptionsContentBottomHook
FullTextSearch::Hooks::IssuesShowDescriptionBottomHook
FullTextSearch::Hooks::SimilarIssuesHelper

FullTextSearch::Searcher
FullTextSearch::SimilarSearcher

class << Setting
  prepend FullTextSearch::SettingsObjectize
end

FullTextSearch.resolver.each do |redmine_class, mapper_class|
  mapper_class.attach(redmine_class)
end
FullTextSearch::CustomFieldCallbacks.attach
Issue.include(FullTextSearch::SimilarSearcher::Model)
Journal.include(FullTextSearch::SimilarSearcher::Model)
SearchController.helper(FullTextSearch::Hooks::SearchHelper)
SearchController.prepend(FullTextSearch::Hooks::ControllerSearchIndex)
IssuesController.helper(FullTextSearch::Hooks::SimilarIssuesHelper)

FullTextSearch::Tag
FullTextSearch::TagType
FullTextSearch::Type

if IssueQuery.method_defined?(:sql_for_any_searchable_field)
  IssueQuery.prepend(FullTextSearch::Hooks::IssueAnySearchable)
end

# Support plugins
if defined?(WikiExtensionsTagRelation)
  # Wiki Extensions tags
  # https://github.com/haru/redmine_wiki_extensions
  WikiExtensionsTagRelation.include(FullTextSearch::PluginWikiExtensionsTagSearchable)
end
