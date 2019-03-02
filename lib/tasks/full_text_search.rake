# -*- ruby -*-

namespace :full_text_search do
  desc "Synchronize"
  task :synchronize => :environment do
    FullTextSearch::SearcherRecord.sync
  end

  namespace :attachment do
    desc "Extract"
    task :extract => :environment do
      options = {}
      id = ENV["ID"]
      options[:ids] = [Integer(id, 10)] if id.present?
      FullTextSearch::SearcherRecord.extract_text(options)
    end
  end
end
