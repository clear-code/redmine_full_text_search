module FullTextSearch
  module Mroonga
    class News < ActiveRecord::Base
      self.table_name = "fts_news"
      belongs_to :news
    end
  end
end
