require File.expand_path('../../test_helper', __FILE__)

class JournalFullTextSearchTest < ActiveSupport::TestCase
  make_my_diffs_pretty!

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
    records = FullTextSearch::SearcherRecord.
                where(original_id: journal.id,
                      original_type: journal.class.name)
    assert_equal([
                   {
                     "project_id" => journal.issue.project_id,
                     "project_name" => journal.issue.project.name,
                     "original_id" => journal.id,
                     "original_type" => journal.class.name,
                     "original_created_on" => journal.created_on,
                     "original_updated_on" => nil,
                     "name" => nil,
                     "description" => nil,
                     "identifier" => nil,
                     "status" => nil,
                     "title" => nil,
                     "summary" => nil,
                     "tracker_id" => nil,
                     "subject" => nil,
                     "author_id" => journal.user_id,
                     "is_private" => nil,
                     "status_id" => journal.journalized.status_id,
                     "issue_id" => journal.journalized_id,
                     "comments" => nil,
                     "short_comments" => nil,
                     "long_comments" => nil,
                     "content" => nil,
                     "notes" => nil,
                     "private_notes" => journal.private_notes,
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
    journal = Journal.generate!
    records = FullTextSearch::SearcherRecord.
                where(original_id: journal.id,
                      original_type: journal.class.name)
    assert_equal(1, records.size)
    journal.destroy!
    assert_equal([], records.reload.to_a)
  end
end
