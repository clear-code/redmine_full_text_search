module FullTextSearch
  module Mroonga
    class FtsWikiPage < ActiveRecord::Base
      belongs_to :wiki_page
    end
  end
end
