# -*- ruby -*-

namespace :full_text_search do
  desc "Tag"
  task :tag => :environment do
    plugin = Redmine::Plugin.find(:full_text_search)
    version = plugin.version
    cd(plugin.directory) do
      sh("git", "tag",
         "-a", "v#{version}",
         "-m", "#{version} has been released!!!")
      sh("git", "push", "--tags")
    end
  end

  desc "Release"
  task :release => :tag

  desc "Destroy"
  task :destroy => :environment do
    batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
    batch_runner.destroy
  end

  wait_queue = lambda do
    queue_adapter = ActiveJob::Base.queue_adapter
    case queue_adapter
    when ActiveJob::QueueAdapters::AsyncAdapter
      scheduler = queue_adapter.instance_variable_get(:@scheduler)
      executor = scheduler.executor
      while executor.query_length > 0
        sleep(1)
      end
    end
  end

  desc "Synchronize"
  task :synchronize => :environment do
    extract_text = ENV["EXTRACT_TEXT"] || "immediate"
    batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
    batch_runner.synchronize(extract_text: extract_text.to_sym)
    wait_queue.call
  end

  namespace :attachment do
    desc "Extract"
    task :extract => :environment do
      options = {}
      id = ENV["ID"]
      options[:ids] = [Integer(id, 10)] if id.present?
      batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
      batch_runner.extract_text(**options)
      wait_queue.call
    end
  end
end
