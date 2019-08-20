require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SimilarWordsFilterTest < ActiveSupport::TestCase
    include PrettyInspectable

    def filter(records, options={})
      filter = SimilarWordsFilter.new
      options.each do |key, value|
        filter.__send__("#{key}=", value)
      end
      filter.run(records)
    end

    def test_generate
      assert_equal([
                     {"source"=>"groonga", "destination"=>"groonga"},
                     {"source"=>"groonga", "destination"=>"mroonga"},
                     {"source"=>"groonga", "destination"=>"rroonga"},
                     {"source"=>"mroonga", "destination"=>"groonga"},
                     {"source"=>"mroonga", "destination"=>"mroonga"},
                     {"source"=>"rroonga", "destination"=>"groonga"},
                     {"source"=>"rroonga", "destination"=>"rroonga"},
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

    def test_ignore_source_number_punctuation_symbol_only
      assert_equal([],
                   filter([
                            {
                              "source" => "(+12.3)",
                              "destination" => "count",
                            }
                          ]))
    end

    def test_ignore_destination_number_punctuation_symbol_only
      assert_equal([],
                   filter([
                            {
                              "source" => "count",
                              "destination" => "(+12.3)",
                            }
                          ]))
    end

    def test_ignore_cosine_threshold
      assert_equal([],
                   filter([
                            {
                              "source" => "Groonga",
                              "destination" => "Mroonga",
                              "cosine" => 0.1,
                            }
                          ]))
    end

    def test_ignore_engine
      assert_equal([],
                   filter([
                            {
                              "source" => "Groonga",
                              "destination" => "Mroonga",
                              "engine" => "BERT",
                            }
                          ],
                          engine: "fastText"))
    end
  end
end
