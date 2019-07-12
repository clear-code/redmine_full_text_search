module FullTextSearch
  class ExtractTextJob < ActiveJob::Base
    queue_as :full_text_search
    queue_with_priority 10

    def perform(id)
      target = Target.find(id)
      mapper = target.mapper.redmine_mapper
      mapper.extract_text
    end
  end
end
