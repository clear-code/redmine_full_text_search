require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class QueryExpansionSynchronizerTest < ActiveSupport::TestCase
    include PrettyInspectable

    def setup
      FtsQueryExpansion.destroy_all
    end

    def synchronize(input)
      synchronizer = QueryExpansionSynchronizer.new(input)
      synchronizer.synchronize
    end

    def test_json_array
      synchronize(StringIO.new(+<<-JSON))
[
["Groonga", "Groonga"],
["Groonga", "Senna"]
]
      JSON
      assert_equal([
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Groonga"),
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Senna"),
                   ],
                   FtsQueryExpansion.order(:id))
    end

    def test_json_object
      synchronize(StringIO.new(+<<-JSON))
[
{"source": "Groonga", "destination": "Groonga"},
{"source": "Groonga", "destination": "Senna"}
]
      JSON
      assert_equal([
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Groonga"),
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Senna"),
                   ],
                   FtsQueryExpansion.order(:id))
    end

    def test_csv
      synchronize(StringIO.new(+<<-CSV))
Groonga,Groonga
Groonga,Senna
      CSV
      assert_equal([
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Groonga"),
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Senna"),
                   ],
                   FtsQueryExpansion.order(:id))
    end

    def test_remove_untouched_entries
      FtsQueryExpansion.create!(source: "Groonga",
                                destination: "Groonga",
                                updated_at: Time.current - 2)
      FtsQueryExpansion.create!(source: "Groonga",
                                destination: "Senna",
                                updated_at: Time.current - 2)
      synchronize(StringIO.new(+<<-CSV))
Groonga,Groonga
      CSV
      assert_equal([
                     FtsQueryExpansion.find_by(source: "Groonga",
                                               destination: "Groonga"),
                   ],
                   FtsQueryExpansion.all)
    end
  end
end
