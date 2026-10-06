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
      queue_adapter.shutdown
    end
  end

  run_batch = lambda do |&block|
    upsert = ENV["UPSERT"] || "immediate"
    extract_text = ENV["EXTRACT_TEXT"] || "immediate"
    project = ENV["PROJECT"]
    type = ENV["TYPE"]
    batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
    block.call(batch_runner,
               project: project,
               type: type,
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

  namespace :similar_issues do
    desc "Synchronize similar issues data"
    task :synchronize => :environment do
      run_batch.call do |batch_runner, **options|
        batch_runner.synchronize_similar_issues(**options)
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

  namespace :change do
    desc "Rename targets for files under directories moved in Subversion. Run this before repository:synchronize"
    task :replay_directories => :environment do
      batch_runner = FullTextSearch::BatchRunner.new(show_progress: true)
      batch_runner.replay_change_directories(project: ENV["PROJECT"])
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

  namespace :semantic do
    namespace :index do
      desc "Create semantic search index (PostgreSQL + PGroonga only)"
      task :create => :environment do
        case FullTextSearch::SemanticIndex.ensure_created(concurrently: ENV["CONCURRENTLY"] == "1")
        when :created
          puts "Created: #{FullTextSearch::SemanticIndex::INDEX_NAME} (model: #{FullTextSearch::SemanticIndex.model})"
        when :exist
          puts "Already exists: #{FullTextSearch::SemanticIndex::INDEX_NAME}"
        else
          puts "Skipped: semantic search index is PostgreSQL + PGroonga only"
        end
      end

      desc "Drop semantic search index"
      task :drop => :environment do
        FullTextSearch::SemanticIndex.ensure_dropped(concurrently: ENV["CONCURRENTLY"] == "1")
      end
    end
  end

  namespace :partition do
    validate_migration_version = lambda do
      plugin = Redmine::Plugin.find(:full_text_search)
      Redmine::Plugin::Migrator.current_plugin = plugin
      migration_version = FullTextSearch::Partition::MIGRATION_VERSION
      return if Redmine::Plugin::Migrator.current_version(plugin) == migration_version
      abort "This task can be used only when the migration is #{migration_version}"
    end

    run_migration = lambda do |direction|
      migration_version = FullTextSearch::Partition::MIGRATION_VERSION
      plugin = Redmine::Plugin.find(:full_text_search)
      require(File.join(plugin.directory,
                        "db",
                        "migrate",
                        "#{migration_version}_partition_fts_targets.rb"))
      PartitionFtsTargets.migrate(direction)
    end

    desc "Partition fts_targets. Run this when the migration for " +
      "partitioning is skipped because Groonga or PGroonga is old"
    task :up => :environment do
      validate_migration_version.call

      partition = FullTextSearch::Partition
      if !Redmine::Database.postgresql?
        puts("Skipped: partitioning is only for PostgreSQL + PGroonga")
      elsif partition.partitioned?
        puts("Already partitioned: #{partition.table_name}")
      elsif !partition.available?
        puts("Skipped: #{partition.requirements_message}")
      else
        run_migration.call(:up)
      end
    end

    desc "Revert the partitioned fts_targets to a normal table"
    task :revert => :environment do
      validate_migration_version.call

      partition = FullTextSearch::Partition
      if !partition.partitioned?
        puts("Skipped: #{partition.table_name} isn't partitioned")
      else
        run_migration.call(:down)
      end
    end
  end
end
