module FullTextSearch
  module Mroonga
    class WikiPage < ActiveRecord::Base
      self.table_name = "fts_wiki_pages"
      belongs_to :wiki_page
    end
  end
end
