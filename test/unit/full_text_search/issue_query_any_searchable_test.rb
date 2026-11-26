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
      subject_groonga = Issue.generate!(subject: "Groonga")
      description_groonga = Issue.generate!(description: "Groonga")
      without_groonga = Issue.generate!(subject: "no-keyword",
                                        description: "no-keyword")
      journal_groonga = Issue.generate!.journals.create!(notes: "Groonga")
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
      expected_issues = [
        subject_groonga,
        description_groonga,
        journal_groonga.issue
      ]
      assert_equal(expected_issues, query.issues)
    end

    def test_and_across_different_fields
      Issue.destroy_all
      # Issue matching keyword1 in subject and keyword2 in journal notes
      issue_matched = Issue.generate!(subject: "SpecialAlphaKeyword", description: "Standard description")
      issue_matched.journals.create!(notes: "SpecialBetaKeyword in journal note")

      # Issue matching only keyword1
      _issue_only_alpha = Issue.generate!(subject: "SpecialAlphaKeyword", description: "Other text")

      # Issue matching only keyword2 in notes
      issue_only_beta = Issue.generate!(subject: "Other subject", description: "Other text")
      issue_only_beta.journals.create!(notes: "SpecialBetaKeyword in journal note")

      query = IssueQuery.new(
        :name => "_",
        :filters => {
          "any_searchable" => {
            :operator => "~",
            :values => ["SpecialAlphaKeyword SpecialBetaKeyword"]
          }
        },
        :sort_criteria => [["id", "asc"]]
      )
      assert_equal([issue_matched], query.issues)
    end
  end
end
