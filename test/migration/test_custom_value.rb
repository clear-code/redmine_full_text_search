require_relative "test_helper"

class TestCustomValueMigration < Test::Unit::TestCase
  include MigrationHelper

  def setup
    setup_db
  end

  def test_issue_for_all
    create_record("Project",
                  name: 'test project',
                  identifier: 'test')
    create_record("IssueCustomField",
                  name: "string-field",
                  field_format: "string",
                  searchable: true,
                  editable: true,
                  is_for_all: true)
    run_script("Tracker.first.custom_fields << IssueCustomField.first")
    run_script("Issue.create!(subject: 'test issue', " +
               "project: Project.first, " +
               "tracker: Tracker.first, " +
               "author: User.first, " +
               "custom_field_values: {IssueCustomField.first.id.to_s => 'value'})")
    remigrate
    assert_equal(["Project", "Issue", "CustomValue"],
                 indexed_types)
  end

  def test_issue_only_project
    create_record("Project",
                  name: 'test project',
                  identifier: 'test')
    create_record("IssueCustomField",
                  name: "string-field",
                  field_format: "string",
                  searchable: true,
                  editable: true)
    run_script("Project.first.issue_custom_fields << IssueCustomField.first")
    run_script("Tracker.first.custom_fields << IssueCustomField.first")
    run_script("Issue.create!(subject: 'test issue', " +
               "project: Project.first, " +
               "tracker: Tracker.first, " +
               "author: User.first, " +
               "custom_field_values: {IssueCustomField.first.id.to_s => 'value'})")
    remigrate
    assert_equal(["Project", "Issue", "CustomValue"],
                 indexed_types)
  end

  def test_project
    create_record("ProjectCustomField",
                  name: "string-field",
                  field_format: "string",
                  searchable: true,
                  editable: true)
    run_script("Project.create!(name: 'test project', " +
               "identifier: 'test', " +
               "custom_field_values: {ProjectCustomField.first.id.to_s => 'value'})")
    remigrate
    assert_equal(["Project", "CustomValue"],
                 indexed_types)
  end
end
