module FullTextSearch
  module Mroonga
    class CustomValue < ActiveRecord::Base
      self.table_name = "fts_custom_values"
      belongs_to :custom_value
    end
  end
end
