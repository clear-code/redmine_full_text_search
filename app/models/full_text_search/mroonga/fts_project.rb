module FullTextSearch
  module Mroonga
    class FtsProject < ActiveRecord::Base
      self.primary_key = :project_id

      belongs_to :project
    end
  end
end
