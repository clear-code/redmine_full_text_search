module FullTextSearch
  module Mroonga
    class Document < ActiveRecord::Base
      self.table_name = "fts_documents"
      belongs_to :document
    end
  end
end
