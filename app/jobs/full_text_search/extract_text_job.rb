module FullTextSearch
  class ExtractTextJob < ActiveJob::Base
    queue_as :default

    def perform(searcher_record_id)
      searcher_record = SearcherRecord.find(searcher_record_id)
      mapper = searcher_record.mapper.redmine_mapper
      mapper.extract_text
    end
  end
end
