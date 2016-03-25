module FullTextSearch
  module Mroonga
    class Project < ActiveRecord::Base
      self.table_name = "fts_projects"
      belongs_to :project
    end
  end
end
