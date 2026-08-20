require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ChangeSubversionTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues
    include TimeValue

    fixtures :enabled_modules
    fixtures :projects
    fixtures :repositories
    fixtures :users
    fixtures :roles

    def setup
      @project = Project.find(3)
    end

    def test_fetch_changesets
      url = self.class.subversion_repository_url
      repository = Repository::Subversion.create(:project => @project,
                                                 :url => url)
      repository.fetch_changesets
      repository_info = RepositoryInfo.new(repository)
      files = repository_info.files.collect do |file|
        change = Change.joins(:changeset)
          .where(path: "/#{file}", changesets: {repository_id: repository.id})
          .order(:id)
          .last
        "#{change.path}@#{change.changeset.identifier}"
      end
      records = Target.
                  where(container_id: repository.id,
                        container_type_id: Type.repository.id).
                  order(source_id: :asc)
      first_change = Change.find_by!(path: "/subversion_test/.project")
      assert_equal([
                     files.sort,
                     {
                       "project_id" => @project.id,
                       "source_id" => first_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2007-09-10T16:54:52.203Z"),
                       "registered_at" => parse_time("2007-09-10T16:54:52.203Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "title" => "#{first_change.path}@#{first_change.changeset.identifier}",
                       "content" => <<-PROJECT,
<?xml version="1.0" encoding="UTF-8"?>\r
<projectDescription>\r
	<name>subversion_test</name>\r
	<comment></comment>\r
	<projects>\r
	</projects>\r
	<buildSpec>\r
	</buildSpec>\r
	<natures>\r
	</natures>\r
</projectDescription>\r
                       PROJECT
                       "custom_field_id" => null_number,
                       "is_private" => null_boolean,
                       "tag_ids" => [],
                     },
                   ],
                   [
                     records.collect(&:title).sort,
                     records.first.attributes.except("id"),
                   ])
    end

    def test_fetch_changesets_sub_path
      url = "#{self.class.subversion_repository_url}/subversion_test"
      repository = Repository::Subversion.create(:project => @project,
                                                 :url => url)
      repository.fetch_changesets
      repository_info = RepositoryInfo.new(repository)
      sub_path_files = repository_info.files.collect do |file|
        change = Change.joins(:changeset)
          .where(path: "/subversion_test/#{file}", changesets: {repository_id: repository.id})
          .order(:id)
          .last
        "#{change.path}@#{change.changeset.identifier}"
      end
      records = Target.
                  where(container_id: repository.id,
                        container_type_id: Type.repository.id).
                  order(source_id: :asc)
      first_change = Change.find_by!(path: "/subversion_test/.project")
      assert_equal([
                     sub_path_files.sort,
                     {
                       "project_id" => @project.id,
                       "source_id" => first_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2007-09-10T16:54:52.203Z"),
                       "registered_at" => parse_time("2007-09-10T16:54:52.203Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "title" => "#{first_change.path}@#{first_change.changeset.identifier}",
                       "content" => <<-PROJECT,
<?xml version="1.0" encoding="UTF-8"?>\r
<projectDescription>\r
	<name>subversion_test</name>\r
	<comment></comment>\r
	<projects>\r
	</projects>\r
	<buildSpec>\r
	</buildSpec>\r
	<natures>\r
	</natures>\r
</projectDescription>\r
                       PROJECT
                       "custom_field_id" => null_number,
                       "is_private" => null_boolean,
                       "tag_ids" => [],
                     },
                   ],
                   [
                     records.collect(&:title).sort,
                     records.first.attributes.except("id"),
                   ])
    end

    def test_move_directory
      Dir.mktmpdir do |dir|
        repository_url = build_move_directory_repository(dir)
        repository = Repository::Subversion.create(:project => @project,
                                                   :url => repository_url)
        repository.fetch_changesets

        move_changeset = repository.changesets.find_by!(revision: "2")
        original_a_change = Change.find_by!(path: "/dir/a.txt")
        original_b_change = Change.find_by!(path: "/dir/b.txt")
        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        b_target = Target.find_by(source_id: original_b_change.id,
                                  source_type_id: Type.change.id)
        assert_equal([
          {
            "project_id" => @project.id,
            "source_id" => original_a_change.id,
            "source_type_id" => Type.change.id,

            # TODO: Support for move
            # "last_modified_at" => move_changeset.committed_on,
            # "registered_at" => move_changeset.committed_on,
            "last_modified_at" => original_a_change.changeset.committed_on,
            "registered_at" => original_a_change.changeset.committed_on,

            "container_id" => repository.id,
            "container_type_id" => Type.repository.id,

            # TODO: Support for move
            # "title" => "/renamed/a.txt@2",
            "title" => "/dir/a.txt@1",

            "content" => "FILE: a.txt\n",
            "custom_field_id" => null_number,
            "is_private" => null_boolean,
            "tag_ids" => [Tag.extension("txt").id],
          },
          {
            "project_id" => @project.id,
            "source_id" => original_b_change.id,
            "source_type_id" => Type.change.id,

            # TODO: Support for move
            # "last_modified_at" => move_changeset.committed_on,
            # "registered_at" => move_changeset.committed_on,
            "last_modified_at" => original_b_change.changeset.committed_on,
            "registered_at" => original_b_change.changeset.committed_on,

            "container_id" => repository.id,
            "container_type_id" => Type.repository.id,

            # TODO: Support for move
            # "title" => "/renamed/b.txt@2",
            "title" => "/dir/b.txt@1",

            "content" => "FILE: b.txt\n",
            "custom_field_id" => null_number,
            "is_private" => null_boolean,
            "tag_ids" => [Tag.extension("txt").id],
          },
        ],
        [
          a_target.attributes.except("id"),
          b_target.attributes.except("id"),
        ])
      end
    end

    def test_delete_directory
      Dir.mktmpdir do |dir|
        repository_url = build_delete_directory_repository(dir)
        repository = Repository::Subversion.create(:project => @project,
                                                   :url => repository_url)
        repository.fetch_changesets

        original_a_change = Change.find_by!(path: "/dir/a.txt")
        original_b_change = Change.find_by!(path: "/dir/b.txt")
        a_target = Target.find_by(source_id: original_a_change.id,
                                  source_type_id: Type.change.id)
        b_target = Target.find_by(source_id: original_b_change.id,
                                  source_type_id: Type.change.id)

        assert_equal([nil, nil], [a_target, b_target])
      end
    end

    private
    def run_command(*args)
      assert(system(*args), "Command failed: #{args.join(' ')}")
    end

    def create_test_repository(dir)
      repository_path = File.join(dir, "repository")
      run_command("svnadmin", "create", repository_path)

      import_path = File.join(dir, "import")
      FileUtils.mkdir_p(import_path)
      File.write(File.join(import_path, "a.txt"), "FILE: a.txt\n")
      File.write(File.join(import_path, "b.txt"), "FILE: b.txt\n")

      repository_url = "file://#{repository_path}"
      run_command("svn", "import",
                  import_path, "#{repository_url}/dir",
                  "-m", "Add dir/{a.txt,b.txt}")
      repository_url
    end

    def build_move_directory_repository(dir)
      repository_url = create_test_repository(dir)
      run_command("svn", "move",
                  "#{repository_url}/dir", "#{repository_url}/renamed",
                  "-m", "Move dir to renamed")
      repository_url
    end

    def build_delete_directory_repository(dir)
      repository_url = create_test_repository(dir)
      run_command("svn", "rm",
                  "#{repository_url}/dir",
                  "-m", "Delete dir")
      repository_url
    end
  end
end
