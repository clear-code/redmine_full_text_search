module FullTextSearch
  class ExtractTextJob < ActiveJob::Base
    queue_as :default

    def perform(id)
      target = Target.find(id)
      mapper = target.mapper.redmine_mapper
      mapper.extract_text
    end
  end
end
