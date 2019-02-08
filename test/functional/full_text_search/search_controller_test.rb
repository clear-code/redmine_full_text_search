require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearchControllerTest < Redmine::ControllerTest
    make_my_diffs_pretty!

    tests SearchController

    fixtures :enumerations
    fixtures :issues
    fixtures :issue_statuses
    fixtures :projects
    fixtures :projects_trackers
    fixtures :trackers
    fixtures :users

    def setup
      SearcherRecord.sync
    end

    def test_search
      # TODO
      get :index
    end
  end
end
