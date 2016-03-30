module FullTextSearch
  module Mroonga
    class FtsJournal < ActiveRecord::Base
      self.primary_key = :journal_id

      belongs_to :journal
    end
  end
end
