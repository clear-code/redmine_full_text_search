module FullTextSearch
  module Mroonga
    class FtsIssue < ActiveRecord::Base
      belongs_to :issue
    end
  end
end
