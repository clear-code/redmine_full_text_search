module FullTextSearch
  module Mroonga
    class FtsMessage < ActiveRecord::Base
      belongs_to :message
    end
  end
end
