require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class JournalTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def test_save
      journal = Journal.generate!
      journal.reload
      records = SearcherRecord.where(original_id: journal.id,
                                     original_type: journal.class.name)
      assert_equal([
                     {
                       "project_id" => journal.issue.project_id,
                       "project_name" => journal.issue.project.name,
                       "original_id" => journal.id,
                       "original_type" => journal.class.name,
                       "original_created_on" => journal.created_on,
                       "original_updated_on" => null_datetime,
                       "name" => null_string,
                       "description" => null_string,
                       "identifier" => null_string,
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => null_number,
                       "subject" => null_string,
                       "author_id" => journal.user_id,
                       "is_private" => null_boolean,
                       "status_id" => journal.journalized.status_id,
                       "issue_id" => journal.journalized_id,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "content" => null_string,
                       "notes" => null_string,
                       "private_notes" => journal.private_notes,
                       "text" => null_string,
                       "value" => null_string,
                       "custom_field_id" => null_number,
                       "container_id" => null_number,
                       "container_type" => null_string,
                       "filename" => null_string,
                     }
                   ],
                   records.all.collect {|record| record.attributes.except("id")})
    end

    def test_destroy
      journal = Journal.generate!
      records = SearcherRecord.where(original_id: journal.id,
                                     original_type: journal.class.name)
      assert_equal(1, records.size)
      journal.destroy!
      assert_equal([], records.reload.to_a)
    end
  end
end
