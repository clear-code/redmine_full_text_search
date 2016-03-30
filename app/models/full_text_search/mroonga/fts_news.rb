module FullTextSearch
  module Mroonga
    class FtsNews < ActiveRecord::Base
      self.primary_key = :news_id

      belongs_to :news
    end
  end
end
