require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SimilarWordsFilterTest < ActiveSupport::TestCase
    include PrettyInspectable

    def filter(records)
      filter = SimilarWordsFilter.new
      filter.run(records)
    end

    def test_generate
      assert_equal([
                     {"source"=>"Groonga", "destination"=>"Groonga"},
                     {"source"=>"Groonga", "destination"=>"Mroonga"},
                     {"source"=>"Groonga", "destination"=>"Rroonga"},
                     {"source"=>"Mroonga", "destination"=>"Groonga"},
                     {"source"=>"Mroonga", "destination"=>"Mroonga"},
                     {"source"=>"Rroonga", "destination"=>"Groonga"},
                     {"source"=>"Rroonga", "destination"=>"Rroonga"},
                   ],
                   filter([
                            {
                              "source" => "Groonga",
                              "destination" => "Mroonga",
                            },
                            {
                              "source" => "Groonga",
                              "destination" => "Rroonga",
                            },
                          ]))
    end

    def test_ignore_source_space
      assert_equal([],
                   filter([
                            {
                              "source" => "Groonga▁MySQL",
                              "destination" => "Mroonga",
                            }
                          ]))
    end

    def test_ignore_destination_space
      assert_equal([],
                   filter([
                            {
                              "source" => "Mroonga",
                              "destination" => "Groonga▁MySQL",
                            }
                          ]))
    end

    def test_ignore_source_one
      assert_equal([],
                   filter([
                            {
                              "source" => "G",
                              "destination" => "Groonga",
                            }
                          ]))
    end

    def test_ignore_destination_one
      assert_equal([],
                   filter([
                            {
                              "source" => "Groonga",
                              "destination" => "G",
                            }
                          ]))
    end

    def test_ignore_source_number_punctuation_only
      assert_equal([],
                   filter([
                            {
                              "source" => "(12.3)",
                              "destination" => "count",
                            }
                          ]))
    end

    def test_ignore_destination_number_punctuation_only
      assert_equal([],
                   filter([
                            {
                              "source" => "count",
                              "destination" => "(12.3)",
                            }
                          ]))
    end

    def test_ignore_destination_include_source
      assert_equal([],
                   filter([
                            {
                              "source" => "Groonga",
                              "destination" => "PGroonga",
                            }
                          ]))
    end
  end
end
