module FullTextSearch
  module Mroonga
    class FtsAttachment < ActiveRecord::Base
      belongs_to :attachment
    end
  end
end
