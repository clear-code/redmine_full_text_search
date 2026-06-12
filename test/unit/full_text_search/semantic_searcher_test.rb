require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SemanticSearcherTest < ActiveSupport::TestCase
    include PrettyInspectable

    fixtures :projects
    fixtures :users

    def setup
      skip("Set SEMANTIC_SEARCH_TEST=1 to run semantic search tests") unless ENV["SEMANTIC_SEARCH_TEST"]
      skip("Semantic search requires PostgreSQL + PGroonga") unless Redmine::Database.postgresql?

      Target.destroy_all
      @user = User.find(1)
      @project = Project.find(1)
    end

    def teardown
      return unless ENV["SEMANTIC_SEARCH_TEST"]
      SemanticIndex.ensure_dropped
    end

    def search(parameters={})
      request = Request.new({semantic: "1"}.merge(parameters))
      request.user = @user
      request.project = @project
      SemanticSearcher.new(request).search
    end

    def test_semantic_search
      cat = Issue.generate!(project: @project,
                            subject: "Pets",
                            description: "The cat sleeps on the warm mat all day.")
      market = Issue.generate!(project: @project,
                               subject: "Economy",
                               description: "Stock market prices rose sharply this quarter.")
      with_settings(plugin_full_text_search: {"semantic_model" => "hf:///groonga/all-MiniLM-L6-v2-Q4_K_M-GGUF"}) do
        SemanticIndex.ensure_created
      end
      assert_equal([cat, market],
                   search({q: "a kitten resting on a rug", limit: 2}).records.collect(&:source_record))
    end
  end
end
