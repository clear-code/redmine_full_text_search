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

  desc "Truncate"
  task :truncate => :environment do
    FullTextSearch::Target.truncate
  end

  wait_queue = lambda do
    queue_adapter = ActiveJob::Base.queue_adapter
    case queue_adapter
    when ActiveJob::QueueAdapters::AsyncAdapter
      scheduler = queue_adapter.instance_variable_get(:@scheduler)
      executor = scheduler.executor
      while executor.queue_length > 0
        sleep(1)
      end
    end
  end

  run_batch = lambda do |&block|
    upsert = ENV["UPSERT"] || "immediate"
    extract_text = ENV["EXTRACT_TEXT"] || "immediate"
    project = ENV["PROJECT"]
    batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
    block.call(batch_runner,
               project: project,
               upsert: upsert.to_sym,
               extract_text: extract_text.to_sym)
    wait_queue.call
  end

  desc "Synchronize"
  task :synchronize => :environment do
    run_batch.call do |batch_runner, **options|
      batch_runner.synchronize(**options)
    end
  end

  namespace :repository do
    desc "Synchronize only repository data"
    task :synchronize => :environment do
      run_batch.call do |batch_runner, **options|
        batch_runner.synchronize_repositories(**options)
      end
    end
  end

  namespace :target do
    desc "Reload targets"
    task :reload => :environment do
      run_batch.call do |batch_runner, **options|
        batch_runner.reload_fts_targets(**options)
      end
    end
  end

  namespace :text do
    desc "Extract texts"
    task :extract => :environment do
      options = {}
      id = ENV["ID"]
      options[:ids] = [Integer(id, 10)] if id.present?
      batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
      batch_runner.extract_text(**options)
      wait_queue.call
    end
  end

  namespace :query_expansion do
    desc "Synchronize query expansion data"
    task :synchronize => :environment do
      input = ENV["INPUT"] || $stdin
      synchronizer = FullTextSearch::QueryExpansionSynchronizer.new(input)
      synchronizer.synchronize
    end
  end
end
