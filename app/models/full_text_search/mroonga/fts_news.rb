module FullTextSearch
  module Mroonga
    class FtsNews < ActiveRecord::Base
      belongs_to :news
    end
  end
end
