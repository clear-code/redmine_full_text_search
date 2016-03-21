Redmine::Plugin.register :full_text_search do
  name 'Full Text Search plugin'
  author 'Kenji Okimoto'
  description 'This plugin provides full text search for Redmine'
  version '0.0.1'
  url 'https://gihub.com/'
  author_url 'https://gihub.com/'
end

Rails.configuration.to_prepare do
  case
  when Redmine::Database.postgresql?
    require "full_text_search/pgroonga"
    %w[projects news issues documents changesets messages journals wiki_pages custom_values].each do |name|
      name.classify.constantize.prepend(FullTextSearch::PGroonga)
    end
  when Redmine::Database.mysql?
    require "full_text_search/mroonga"
    %w[projects news issues documents changesets messages journals wiki_pages custom_values].each do |name|
      name.classify.constantize.prepend(FullTextSearch::Mroonga)
    end
  else
    # Do nothing
  end
end
