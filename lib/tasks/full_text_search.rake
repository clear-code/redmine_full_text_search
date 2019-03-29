# -*- ruby -*-

namespace :full_text_search do
  desc "Destroy"
  task :destroy => :environment do
    batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
    batch_runner.destroy
  end

  desc "Synchronize"
  task :synchronize => :environment do
    batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
    batch_runner.synchronize(extract_text: :immediate)
  end

  namespace :attachment do
    desc "Extract"
    task :extract => :environment do
      options = {}
      id = ENV["ID"]
      options[:ids] = [Integer(id, 10)] if id.present?
      batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
      batch_runner.extract_text(**options)
    end
  end
end
