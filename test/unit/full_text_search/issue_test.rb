require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueTest < ActiveSupport::TestCase
    make_my_diffs_pretty!

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
                       "name" => nil,
                       "description" => issue.description,
                       "identifier" => nil,
                       "status" => nil,
                       "title" => nil,
                       "summary" => nil,
                       "tracker_id" => issue.tracker_id,
                       "subject" => issue.subject,
                       "author_id" => issue.author_id,
                       "is_private" => issue.is_private,
                       "status_id" => issue.status_id,
                       "issue_id" => issue.id,
                       "comments" => nil,
                       "short_comments" => nil,
                       "long_comments" => nil,
                       "content" => nil,
                       "notes" => nil,
                       "private_notes" => nil,
                       "text" => nil,
                       "value" => nil,
                       "custom_field_id" => nil,
                       "container_id" => nil,
                       "container_type" => nil,
                       "filename" => nil,
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
