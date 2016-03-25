module FullTextSearch
  module Mroonga
    class FtsJournal < ActiveRecord::Base
      belongs_to :journal
    end
  end
end
