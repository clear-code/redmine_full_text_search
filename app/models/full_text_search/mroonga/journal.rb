module FullTextSearch
  module Mroonga
    class Journal < ActiveRecord::Base
      self.table_name = "fts_journals"
      belongs_to :journal
    end
  end
end
