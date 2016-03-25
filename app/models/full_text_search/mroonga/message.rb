module FullTextSearch
  module Mroonga
    class Message < ActiveRecord::Base
      self.table_name = "fts_messages"
      belongs_to :message
    end
  end
end
