module FullTextSearch
  module Model
    def self.included(base)
      base.class_eval do
        synchronizer = Synchronizer.new
        after_save do |record|
          synchronizer.upsert(record)
        end
        after_destroy do |record|
          synchronizer.destroy(record)
        end
      end
    end
  end
end
