module FullTextSearch
  class UpsertTargetJob < ActiveJob::Base
    queue_as :full_text_search
    queue_with_priority 15

    discard_on ActiveRecord::RecordNotFound

    def perform(mapper_class_name, source_id)
      mapper_class = mapper_class_name.constantize
      source = mapper_class.redmine_class.find(source_id)
      mapper = mapper_class.redmine_mapper(source)
      mapper.upsert_fts_target
    end
  end
end
