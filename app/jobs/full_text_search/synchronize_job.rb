module FullTextSearch
  class SynchronizeJob < ActiveJob::Base
    queue_as :full_text_search

    def perform(options = {})
      upsert = options[:upsert] || "immediate"
      extract_text = options[:extract_text] || "immediate"
      batch_runner = FullTextSearch::BatchRunner.new(show_progress: false)
      batch_runner.synchronize(
        upsert: upsert.to_sym,
        extract_text: extract_text.to_sym
      )
    end
  end
end
