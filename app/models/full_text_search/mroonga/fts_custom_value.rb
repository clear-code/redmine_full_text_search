module FullTextSearch
  module Mroonga
    class FtsCustomValue < ActiveRecord::Base
      self.primary_key = :custom_value_id

      belongs_to :custom_value
    end
  end
end
