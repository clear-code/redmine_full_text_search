module FullTextSearch
  module Mroonga
    class FtsWikiPage < ActiveRecord::Base
      self.primary_key = :wiki_page_id

      belongs_to :wiki_page
    end
  end
end
