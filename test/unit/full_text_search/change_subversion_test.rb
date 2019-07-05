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
      records = Target.
                  where(container_id: repository.id,
                        container_type_id: Type.repository.id).
                  order(source_id: :asc)
      first_change = Change.find_by!(path: "/subversion_test/.project")
      last_change = Change.find_by!(path: "/subversion_test/[folder_with_brackets]/README.txt")
      assert_equal([
                     [
                       "/subversion_test/.project",
                       "/subversion_test/folder/subfolder/rubylogo.gif",
                       "/subversion_test/textfile.txt",
                       "/subversion_test/folder/helloworld.rb",
                       "/subversion_test/helloworld.c",
                       "/subversion_test/folder/subfolder/journals_controller.rb",
                       "/subversion_test/[folder_with_brackets]/README.txt",
                     ],
                     {
                       "project_id" => @project.id,
                       "source_id" => first_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2007-09-10T16:54:52.203Z"),
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
                     {
                       "project_id" => @project.id,
                       "source_id" => last_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2010-06-20T09:13:43.065362Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "custom_field_id" => null_number,
                       "title" => "/subversion_test/[folder_with_brackets]/README.txt",
                       "content" => <<-CONTENT,
This file should be accessible for Redmine, although its folder contains square
brackets.
                       CONTENT
                       "is_private" => null_boolean,
                       "tag_ids" => [Tag.extension("txt").id],
                     },
                   ],
                   [
                     records.collect(&:title),
                     records.first.attributes.except("id"),
                     records.last.attributes.except("id"),
                   ])
    end

    def test_fetch_changesets_sub_path
      url = "#{self.class.subversion_repository_url}/subversion_test"
      repository = Repository::Subversion.create(:project => @project,
                                                 :url => url)
      repository.fetch_changesets
      records = Target.
                  where(container_id: repository.id,
                        container_type_id: Type.repository.id).
                  order(source_id: :asc)
      first_change = Change.find_by!(path: "/subversion_test/.project")
      last_change = Change.find_by!(path: "/subversion_test/[folder_with_brackets]/README.txt")
      assert_equal([
                     [
                       "/subversion_test/.project",
                       "/subversion_test/folder/subfolder/rubylogo.gif",
                       "/subversion_test/textfile.txt",
                       "/subversion_test/folder/helloworld.rb",
                       "/subversion_test/helloworld.c",
                       "/subversion_test/folder/subfolder/journals_controller.rb",
                       "/subversion_test/[folder_with_brackets]/README.txt",
                     ],
                     {
                       "project_id" => @project.id,
                       "source_id" => first_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2007-09-10T16:54:52.203Z"),
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
                     {
                       "project_id" => @project.id,
                       "source_id" => last_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2010-06-20T09:13:43.065362Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "custom_field_id" => null_number,
                       "title" => "/subversion_test/[folder_with_brackets]/README.txt",
                       "content" => <<-CONTENT,
This file should be accessible for Redmine, although its folder contains square
brackets.
                       CONTENT
                       "is_private" => null_boolean,
                       "tag_ids" => [Tag.extension("txt").id],
                     },
                   ],
                   [
                     records.collect(&:title),
                     records.first.attributes.except("id"),
                     records.last.attributes.except("id"),
                   ])
    end
  end
end
