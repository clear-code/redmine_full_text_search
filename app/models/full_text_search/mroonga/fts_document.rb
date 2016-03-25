module FullTextSearch
  module Mroonga
    class FtsDocument < ActiveRecord::Base
      belongs_to :document
    end
  end
end
