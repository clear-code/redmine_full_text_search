module FullTextSearch
  class CreatePartitionJob < ActiveJob::Base
    queue_as :full_text_search
    queue_with_priority 10

    def perform(year)
      Partition.ensure_created(year)
    end
  end
end
