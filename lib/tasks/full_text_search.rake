# -*- ruby -*-

namespace :full_text_search do
  desc "Synchronize"
  task :synchronize => :environment do
    FullTextSearch::SearcherRecord.sync
  end

  namespace :attachment do
    desc "Extract"
    task :extract => :environment do
      FullTextSearch::SearcherRecord.extract_text
    end
  end
end
