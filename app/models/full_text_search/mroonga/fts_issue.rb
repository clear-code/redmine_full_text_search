module FullTextSearch
  module Mroonga
    class FtsIssue < ActiveRecord::Base
      self.primary_key = :issue_id

      belongs_to :issue
    end
  end
end
