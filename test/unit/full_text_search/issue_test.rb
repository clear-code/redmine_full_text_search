require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueTest < ActiveSupport::TestCase
    include PrettyInspectable
    include NullValues

    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def test_save
      issue = Issue.generate!
      issue.reload
      records = SearcherRecord.where(original_id: issue.id,
                                     original_type: issue.class.name)
      assert_equal([
                     {
                       "project_id" => issue.project_id,
                       "project_name" => issue.project.name,
                       "original_id" => issue.id,
                       "original_type" => issue.class.name,
                       "original_created_on" => issue.created_on,
                       "original_updated_on" => issue.updated_on,
                       "name" => null_string,
                       "description" => issue.description || null_string,
                       "identifier" => null_string,
                       "status" => null_number,
                       "title" => null_string,
                       "summary" => null_string,
                       "tracker_id" => issue.tracker_id,
                       "subject" => issue.subject,
                       "author_id" => issue.author_id,
                       "is_private" => issue.is_private,
                       "status_id" => issue.status_id,
                       "issue_id" => issue.id,
                       "comments" => null_string,
                       "short_comments" => null_string,
                       "long_comments" => null_string,
                       "content" => null_string,
                       "notes" => null_string,
                       "private_notes" => null_boolean,
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
      issue = Issue.generate!
      records = SearcherRecord.where(original_id: issue.id,
                                     original_type: issue.class.name)
      assert_equal(1, records.size)
      issue.destroy!
      assert_equal([], records.reload.to_a)
    end
  end
end
