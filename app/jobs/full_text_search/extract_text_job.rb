module FullTextSearch
  class ExtractTextJob < ActiveJob::Base
    use_queue_priority = true
    if Rails::VERSION::MAJOR == 4 and Rails.env == "test"
      use_queue_priority = false
    end
    queue_with_priority 10 if use_queue_priority

    def perform(id)
      target = Target.find(id)
      mapper = target.mapper.redmine_mapper
      mapper.extract_text
    end
  end
end
