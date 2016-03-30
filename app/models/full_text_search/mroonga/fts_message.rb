module FullTextSearch
  module Mroonga
    class FtsMessage < ActiveRecord::Base
      self.primary_key = :message_id

      belongs_to :message
    end
  end
end
