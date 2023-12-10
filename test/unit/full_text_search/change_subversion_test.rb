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
        "/#{file}"
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
                       "created_at" => parse_time("2007-12-14T09:24:01Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "title" => "/subversion_test/.project",
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
        "/subversion_test/#{file}"
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
                       "created_at" => parse_time("2007-12-14T09:24:01Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "title" => "/subversion_test/.project",
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
  end
end
