module FullTextSearch
  module Mroonga
    class Issue < ActiveRecord::Base
      self.table_name = "fts_issues"
      belongs_to :issue
    end
  end
end
