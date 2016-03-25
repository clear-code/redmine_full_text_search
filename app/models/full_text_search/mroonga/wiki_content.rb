module FullTextSearch
  module Mroonga
    class WikiContent < ActiveRecord::Base
      self.table_name = "fts_wiki_contents"
      belongs_to :wiki_content
    end
  end
end
