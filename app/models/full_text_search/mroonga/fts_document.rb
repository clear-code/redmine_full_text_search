module FullTextSearch
  module Mroonga
    class FtsDocument < ActiveRecord::Base
      self.primary_key = :document_id

      belongs_to :document
    end
  end
end
