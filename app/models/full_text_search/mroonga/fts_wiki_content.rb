module FullTextSearch
  module Mroonga
    class FtsWikiContent < ActiveRecord::Base
      self.primary_key = :wiki_content_id

      belongs_to :wiki_content
    end
  end
end
