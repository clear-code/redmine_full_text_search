module FullTextSearch
  module Mroonga
    class FtsWikiContent < ActiveRecord::Base
      belongs_to :wiki_content
    end
  end
end
