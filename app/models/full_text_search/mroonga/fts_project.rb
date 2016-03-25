module FullTextSearch
  module Mroonga
    class FtsProject < ActiveRecord::Base
      belongs_to :project
    end
  end
end
