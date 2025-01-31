require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearcherTest < ActiveSupport::TestCase
    setup do
      if Gem::Version.new(Redmine::VERSION) < Gem::Version.new("5.1")
        skip("Need Redmine 5.1 or later")
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
