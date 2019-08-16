class CreateFtsQueryExpansions < ActiveRecord::Migration[5.2]
  def change
    if Redmine::Database.mysql?
      options = "ENGINE=Mroonga"
    else
      options = nil
    end
    create_table :fts_query_expansions, options: options do |t|
      if Redmine::Database.mysql?
        t.string :source, null: false
        t.string :destination, null: false
      else
        t.text :source, null: false
        t.text :destination, null: false
      end
      t.timestamps
      if Redmine::Database.mysql?
        t.index [:source], comment: "NORMALIZER 'NormalizerNFKC121'"
        t.index [:destination], comment: "NORMALIZER 'NormalizerNFKC121'"
      else
        t.index [
                  "source pgroonga_text_term_search_ops_v2",
                  "destination pgroonga_text_term_search_ops_v2",
                ].join(", "),
                using: "PGroonga",
                name: "fts_query_expansions_index_pgroonga"
      end
      t.index :updated_at
    end
  end
end
