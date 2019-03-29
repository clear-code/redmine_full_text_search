# -*- ruby -*-

namespace :full_text_search do
  desc "Tag"
  task :tag do
    version = Redmine::Plugin.find(:full_text_search).version
    sh("git", "tag",
       "-a", version,
       "-m", "#{version} has been released!!!")
    sh("git", "push", "--tags")
  end

  desc "Release"
  task :release => :tag

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
