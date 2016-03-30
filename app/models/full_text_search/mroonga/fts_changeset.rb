module FullTextSearch
  module Mroonga
    class FtsChangeset < ActiveRecord::Base
      self.primary_key = :changeset_id

      belongs_to :changeset
    end
  end
end
