module FullTextSearch
  module Mroonga
    class FtsChangeset < ActiveRecord::Base
      belongs_to :changeset
    end
  end
end
