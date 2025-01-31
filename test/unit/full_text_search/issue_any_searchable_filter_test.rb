require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearcherTest < ActiveSupport::TestCase
    setup do
      unless IssueQuery.method_defined?(:sql_for_any_searchable_field)
        skip("Required feature 'sql_for_any_searchable_field' does not exist.")
      end
    end

    def test_filter_any_searchable
      Issue.destroy_all
      issue_with_searched_word_in_subject = Issue.generate!(subject: "Groonga")
      issue_with_searched_word_in_description =
        Issue.generate!(description: "Groonga")
      issue_without_searched_word =
        Issue.generate!(subject: "no-keyword",
                        description: "no-keyword")
      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["Groonga"]
          }
        }
      )
      searched_issues = Issue.where(query.statement).order(:id)
      issues_with_searched_keywords = [
        issue_with_searched_word_in_subject,
        issue_with_searched_word_in_description
      ]
      assert_equal(issues_with_searched_keywords, searched_issues)
    end
  end
end
