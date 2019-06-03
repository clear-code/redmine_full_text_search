require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ChangeTest < ActiveSupport::TestCase
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
      url = self.class.subversion_repository_url
      @repository = Repository::Subversion.create(:project => @project,
                                                  :url => url)
    end

    def test_fetch_changesets
      @repository.fetch_changesets
      records = Target.
                  where(container_id: @repository.id,
                        container_type_id: Type.repository.id).
                  order(source_id: :asc)
      first_change = Change.find_by(path: "/subversion_test/.project")
      last_change = Change.find_by(path: "/subversion_test/[folder_with_brackets]/README.txt")
      assert_equal([
                     [
                       "/subversion_test/.project",
                       "/subversion_test/folder/subfolder/rubylogo.gif",
                       "/subversion_test/helloworld.rb",
                       "/subversion_test/textfile.txt",
                       "/subversion_test/folder/greeter.rb",
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
                       "container_id" => @repository.id,
                       "container_type_id" => Type.repository.id,
                       "title" => "/subversion_test/.project",
                       "custom_field_id" => null_number,
                       "is_private" => null_boolean,
                       "tag_ids" => [],
                     },
                     {
                       "project_id" => @project.id,
                       "source_id" => last_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2010-06-20T09:13:43.065362Z"),
                       "container_id" => @repository.id,
                       "container_type_id" => Type.repository.id,
                       "custom_field_id" => null_number,
                       "title" => "/subversion_test/[folder_with_brackets]/README.txt",
                       "is_private" => null_boolean,
                       "tag_ids" => [Tag.extension("txt").id],
                     },
                   ],
                   [
                     records.collect(&:title),
                     records.first.attributes.except("id", "content"),
                     records.last.attributes.except("id", "content"),
                   ])
    end
  end
end
