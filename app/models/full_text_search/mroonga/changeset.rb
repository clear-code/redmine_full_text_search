module FullTextSearch
  module Mroonga
    class Changeset < ActiveRecord::Base
      self.table_name = "fts_changesets"
      belongs_to :changeset
    end
  end
end
