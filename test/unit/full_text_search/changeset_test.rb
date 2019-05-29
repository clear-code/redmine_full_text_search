require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class ChangesetTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues
    include TimeValue

    fixtures :enabled_modules
    fixtures :projects
    fixtures :repositories
    fixtures :users
    fixtures :roles

    def test_save
      changeset = Changeset.generate! do |generating_changeset|
        generating_changeset.comments = "Fix a memory leak\n\nThis is critical."
        generating_changeset.committer = User.find(2).login
      end
      changeset.reload
      records = SearcherRecord.where(original_id: changeset.id,
                                     original_type: "Changeset")
      assert_equal([
                     {
                       "project_id" => changeset.repository.project_id,
                       "project_name" => changeset.repository.project.name,
                       "original_id" => changeset.id,
                       "original_type" => changeset.class.name,
                       "original_created_on" => changeset.committed_on,
                       "original_updated_on" => null_datetime,
                       "name" => null_string,
                       "description" => null_string,
                       "identifier" => null_string,
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => changeset.user_id,
                       "is_private" => null_boolean,
                       "status_id" => null_number,
                       "issue_id" => null_number,
                       "comments" => "Fix a memory leak\n\nThis is critical.",
                       "short_comments" => "Fix a memory leak",
                       "long_comments" => "This is critical.",
                       "content" => null_string,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
                       "text" => null_string,
                       "value" => null_string,
                       "custom_field_id" => null_number,
                       "container_id" => null_number,
                       "container_type" => null_string,
                       "filename" => null_string,
                     },
                   ],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_destroy
      changeset = Changeset.generate!
      records = SearcherRecord.where(original_id: changeset.id,
                                     original_type: changeset.class.name)
      assert_equal(1, records.size)
      changeset.destroy!
      assert_equal([], records.reload.to_a)
    end
  end
end
