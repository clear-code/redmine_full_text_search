require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ChangeGitTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues
    include TimeValue

    fixtures :enabled_modules
    fixtures :projects
    fixtures :repositories
    fixtures :users
    fixtures :roles

    def setup
      unless Target.multiple_column_unique_key_update_is_supported?
        skip("Need Mroonga 9.05 or later")
      end
      @project = Project.find(3)
    end

    def test_fetch_changesets
      url = self.class.repository_path("git")
      repository = Repository::Git.create(:project => @project,
                                          :url => url)
      repository.fetch_changesets
      records = Target.
                  where(container_id: repository.id,
                        container_type_id: Type.repository.id).
                  order(source_id: :asc)
      first_change = Change.find_by!(path: "images/edit.png")
      last_change = Change.where(path: "issue-8857/test01.txt").last
      assert_equal([
                     [
                       "images/edit.png",
                       "copied_README",
                       "new_file.txt",
                       "renamed_test.txt",
                       "sources/watchers_controller.rb",
                       "this_is_a_really_long_and_verbose_directory_name/this_is_because_of_a_simple_reason/it_is_testing_the_ability_of_redmine_to_use_really_long_path_names/These_names_exceed_255_chars_in_total/That_is_the_single_reason_why_we_have_this_directory_here/But_there_might_also_be_additonal_reasons/And_then_there_is_not_even_somthing_funny_in_here.txt",
                       "filemane with spaces.txt",
                       " filename with a leading space.txt ",
                       "latin-1/test00.txt",
                       "README",
                       "latin-1-dir/make-latin-1-file.rb",
                       "issue-8857/test00.txt",
                       "issue-8857/test01.txt",
                     ],
                     {
                       "project_id" => @project.id,
                       "source_id" => first_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2007-12-14T09:24:01Z"),
                       "created_at" => parse_time("2007-12-14T09:24:01Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "title" => "images/edit.png",
                       "content" => "",
                       "custom_field_id" => null_number,
                       "is_private" => null_boolean,
                       "tag_ids" => [Tag.extension("png").id],
                     },
                     {
                       "project_id" => @project.id,
                       "source_id" => last_change.id,
                       "source_type_id" => Type.change.id,
                       "last_modified_at" => parse_time("2011-01-01T03:00:00Z"),
                       "created_at" => parse_time("2011-01-01T03:00:00Z"),
                       "container_id" => repository.id,
                       "container_type_id" => Type.repository.id,
                       "custom_field_id" => null_number,
                       "title" => "issue-8857/test01.txt",
                       "content" => <<-CONTENT,
test
test
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
