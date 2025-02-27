require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class IssueQueryAnySearchableTest < ActiveSupport::TestCase
    setup do
      unless IssueQuery.method_defined?(:sql_for_any_searchable_field)
        skip("Required feature 'sql_for_any_searchable_field' does not exist.")
      end
    end

    def test_or_one_word
      Issue.destroy_all
      issue_with_searched_word_in_subject = Issue.generate!(subject: "Groonga")
      issue_with_searched_word_in_description =
        Issue.generate!(description: "Groonga")
      issue_without_searched_word =
        Issue.generate!(subject: "no-keyword",
                        description: "no-keyword")
      issue_has_journal_with_searched_word =
        Issue.generate!(subject: "no-keyword",
                        description: "no-keyword")
      issue_has_journal_with_searched_word.journals.create!(notes: "Groonga")
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["Groonga"]
          }
        },
        :sort_criteria => [["id", "asc"]]
      )
      issues_with_searched_keywords = [
        issue_with_searched_word_in_subject,
        issue_with_searched_word_in_description,
        issue_has_journal_with_searched_word
      ]
      assert_equal(issues_with_searched_keywords, query.issues)
    end
  end
end
