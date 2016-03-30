module FullTextSearch
  module Mroonga
    class FtsAttachment < ActiveRecord::Base
      self.primary_key = :attachment_id

      belongs_to :attachment
    end
  end
end
