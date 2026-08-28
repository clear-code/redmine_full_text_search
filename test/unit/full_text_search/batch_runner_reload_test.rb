require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class BatchRunnerReloadTest < ActiveSupport::TestCase
    include SubversionRepositoryBuilder

    fixtures :enabled_modules
    fixtures :projects
    fixtures :repositories
    fixtures :users
    fixtures :roles

    def setup
      Target.destroy_all
      @project = Project.find(3)
    end

    def test_reload_moved_directory
      Dir.mktmpdir do |dir|
        repository_url = build_move_directory_repository(dir)
        repository = Repository::Subversion.create(:project => @project,
                                                   :url => repository_url)
        repository.fetch_changesets

        original_a_change = Change.find_by!(path: "/dir/a.txt")
        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        assert_equal("/renamed/a.txt@2", a_target.title)

        runner = BatchRunner.new
        assert_no_difference("Target.count") do
          runner.reload_fts_targets(project: @project)
        end

        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        assert_equal("/renamed/a.txt@2", a_target.title)
      end
    end

    def test_reload_moved_directory_twice
      Dir.mktmpdir do |dir|
        repository_url = build_move_directory_twice_repository(dir)
        repository = Repository::Subversion.create(:project => @project,
                                                   :url => repository_url)
        repository.fetch_changesets

        original_a_change = Change.find_by!(path: "/dir/a.txt")
        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        assert_equal("/rerenamed/a.txt@3", a_target.title)

        runner = BatchRunner.new
        assert_no_difference("Target.count") do
          runner.reload_fts_targets(project: @project)
        end

        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        assert_equal("/rerenamed/a.txt@3", a_target.title)
      end
    end

    def test_replay_change_directories_restores_title
      Dir.mktmpdir do |dir|
        repository_url = build_move_directory_repository(dir)
        repository = Repository::Subversion.create(:project => @project,
                                                   :url => repository_url)
        repository.fetch_changesets

        original_a_change = Change.find_by!(path: "/dir/a.txt")
        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)

        # Update it to simulate the old revision.
        a_target.update!(title: "/dir/a.txt@1")

        runner = BatchRunner.new
        assert_no_difference("Target.count") do
          runner.replay_change_directories(project: @project)
        end

        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        assert_equal("/renamed/a.txt@2", a_target.title)
      end
    end

    def test_replay_change_directories_keeps_replaced_directory
      Dir.mktmpdir do |dir|
        repository_url = build_replace_directory_with_move_repository(dir)
        repository = Repository::Subversion.create(:project => @project,
                                                   :url => repository_url)
        repository.fetch_changesets

        expected = Target
          .where(source_type_id: Type.change.id,
                 container_id: repository.id,
                 container_type_id: Type.repository.id)
          .order(:id)
          .pluck(:title)

        runner = BatchRunner.new
        assert_no_difference("Target.count") do
          runner.replay_change_directories(project: @project)
        end

        actual = Target
          .where(source_type_id: Type.change.id,
                 container_id: repository.id,
                 container_type_id: Type.repository.id)
          .order(:id)
          .pluck(:title)
        assert_equal(expected, actual)
      end
    end
  end
end
