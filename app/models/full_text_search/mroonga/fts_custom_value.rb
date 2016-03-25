module FullTextSearch
  module Mroonga
    class FtsCustomValue < ActiveRecord::Base
      belongs_to :custom_value
    end
  end
end
