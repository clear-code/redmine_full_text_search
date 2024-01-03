require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearcherTest < ActiveSupport::TestCase
    include PrettyInspectable

    fixtures :attachments
    fixtures :boards
    fixtures :changes
    fixtures :changesets
    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_values
    fixtures :documents
    fixtures :enabled_modules
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :journals
    fixtures :members
    fixtures :messages
    fixtures :news
    fixtures :projects
    fixtures :projects_trackers
    fixtures :repositories
    fixtures :roles
    fixtures :trackers
    fixtures :users
    fixtures :wiki_pages
    fixtures :wikis

    def setup
      Target.destroy_all
      runner = BatchRunner.new
      runner.synchronize

      @user = User.find(4)
      @project = Project.find(1)
    end

    def search(parameters={})
      request = Request.new(parameters)
      request.user = @user
      request.project = @project
      Searcher.new(request).search
    end

    def test_open_issues
      parameters = {
        issues: "1",
        limit: "-1",
      }
      all_issue_targets = search(parameters).records
      open_issue_targets = search(parameters.merge(open_issues: "1")).records
      diff_targets = all_issue_targets - open_issue_targets
      assert_equal(@project.issues.open(false).order(:id).to_a,
                   diff_targets.collect(&:source_record).sort_by(&:id))
    end

    def test_query_expansion
      FtsQueryExpansion.create!(source: "press", destination: "press")
      FtsQueryExpansion.create!(source: "press", destination: "print")
      parameters = {
        q: "press",
      }
      press_or_print_targets = search(parameters).records
      print_issues = @project
                       .issues
                       .where("description LIKE '%print%'")
                       .order(:id)
                       .to_a
      assert_equal(print_issues,
                   press_or_print_targets.collect(&:source_record).sort_by(&:id))
    end

    def test_syntax_error_query
      issue = Issue.generate!(description: "AAA aaa(zzz ZZZ")
      parameters = {
        q: "aaa(zzz",
      }
      targets = search(parameters).records
      assert_equal([issue],
                   targets.collect(&:source_record).sort_by(&:id))
    end

    def test_order_registered_time_desc
      parameters = {
        order_target: "registered_time",
        order_type: "desc",
        news: "1",
        attachments: "0",
        limit: "-1"
      }
      targets = search(parameters).records
      searched_news = targets.collect(&:source_record)
      ordered_news = @project
                       .news
                       .order(created_on: :desc)
      assert_equal(ordered_news, searched_news)
    end

    def test_order_registered_time_asc
      parameters = {
        order_target: "registered_time",
        order_type: "asc",
        news: "1",
        attachments: "0",
        limit: "-1"
      }
      targets = search(parameters).records
      searched_news = targets.collect(&:source_record)
      ordered_news = @project
                       .news
                       .order(created_on: :asc)
      assert_equal(ordered_news, searched_news)
    end

    def test_order_last_modified_time_desc
      parameters = {
        order_target: "last_modified_time",
        order_type: "desc",
        news: "1",
        attachments: "0",
        limit: "-1"
      }
      targets = search(parameters).records
      searched_news = targets.collect(&:source_record)
      ordered_news = @project
                       .news
                       .order(created_on: :desc)
      assert_equal(ordered_news, searched_news)
    end

    def test_order_last_modified_time_asc
      parameters = {
        order_target: "last_modified_time",
        order_type: "asc",
        news: "1",
        attachments: "0",
        limit: "-1"
      }
      targets = search(parameters).records
      searched_news = targets.collect(&:source_record)
      ordered_news = @project
                       .news
                       .order(created_on: :asc)
      assert_equal(ordered_news, searched_news)
    end

    def test_order_score_desc
      Issue.destroy_all
      issue_with_high_score = Issue.generate!(description: "score score score")
      issue_with_middle_score = Issue.generate!(description: "score score")
      issue_with_low_score = Issue.generate!(description: "score")
      parameters = {
        q: "score",
        order_target: "score",
        order_type: "desc",
        issues: "1",
        limit: "-1"
      }
      targets = search(parameters).records
      searched_issues = targets.collect(&:source_record)
      ordered_issues = [issue_with_high_score, issue_with_middle_score, issue_with_low_score]
      assert_equal(ordered_issues, searched_issues)
    end

    def test_order_score_asc
      Issue.destroy_all
      issue_with_high_score = Issue.generate!(description: "score score score")
      issue_with_middle_score = Issue.generate!(description: "score score")
      issue_with_low_score = Issue.generate!(description: "score")
      parameters = {
        q: "score",
        order_target: "score",
        order_type: "asc",
        issues: "1",
        limit: "-1"
      }
      targets = search(parameters).records
      searched_issues = targets.collect(&:source_record)
      ordered_issues = [issue_with_low_score, issue_with_middle_score, issue_with_high_score]
      assert_equal(ordered_issues, searched_issues)
    end
  end
end
