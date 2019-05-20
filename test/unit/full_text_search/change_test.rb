require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ChangeTest < ActiveSupport::TestCase
    make_my_diffs_pretty!

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
      records = SearcherRecord.where(container_id: @repository.id,
                                     container_type: "Repository")
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
                       "project_name" => @project.name,
                       "original_id" => 2,
                       "original_type" => "Change",
                       "original_created_on" => parse_time("2007-09-10T16:54:52.203Z"),
                       "original_updated_on" => parse_time("2007-09-10T16:54:52.203Z"),
                       "name" => null_string,
                       "description" => null_string,
                       "identifier" => "2",
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => null_number,
                       "is_private" => null_boolean,
                       "status_id" => null_number,
                       "issue_id" => null_number,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
                       "text" => null_string,
                       "value" => null_string,
                       "custom_field_id" => null_number,
                       "container_id" => @repository.id,
                       "container_type" => "Repository",
                       "filename" => "/subversion_test/.project",
                     },
                     {
                       "project_id" => @project.id,
                       "project_name" => @project.name,
                       "original_id" => 20,
                       "original_type" => "Change",
                       "original_created_on" => parse_time("2010-06-20T09:13:43.065362Z"),
                       "original_updated_on" => parse_time("2010-06-20T09:13:43.065362Z"),
                       "name" => null_string,
                       "description" => null_string,
                       "identifier" => "11",
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => null_number,
                       "is_private" => null_boolean,
                       "status_id" => null_number,
                       "issue_id" => null_number,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
                       "text" => null_string,
                       "value" => null_string,
                       "custom_field_id" => null_number,
                       "container_id" => @repository.id,
                       "container_type" => "Repository",
                       "filename" => "/subversion_test/[folder_with_brackets]/README.txt",
                     },
                   ],
                   [
                     records.collect(&:filename),
                     records.first.attributes.except("id", "content"),
                     records.last.attributes.except("id", "content"),
                   ])
    end
  end
end
