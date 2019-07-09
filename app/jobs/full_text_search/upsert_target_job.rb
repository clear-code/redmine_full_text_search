module FullTextSearch
  class UpsertTargetJob < ActiveJob::Base
    use_queue_priority = true
    if Rails::VERSION::MAJOR == 4 and Rails.env == "test"
      use_queue_priority = false
    end
    queue_with_priority 10 if use_queue_priority

    def perform(mapper_class_name, source_id)
      mapper_class = mapper_class_name.constantize
      source = mapper_class.redmine_class.find(source_id)
      mapper = mapper_class.redmine_mapper(source)
      mapper.upsert_fts_target
    end
  end
end
