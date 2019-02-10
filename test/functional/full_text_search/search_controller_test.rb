require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearchControllerTest < Redmine::ControllerTest
    include GroongaCommandExecutable

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
      execute_groonga_command("plugin_register functions/vector")
    end

    def test_search
      get :index
      # TODO: assert
    end
  end
end
