# For auto load
FullTextSearch::Migration

class AddNameIndexToFtsTags < ActiveRecord::Migration[5.2]
  def change
    return if reverting? and !table_exists?(:fts_tags)

    if Redmine::Database.mysql?
      add_index :fts_tags,
                :name,
                type: "fulltext",
                comment: "NORMALIZER 'NormalizerNFKC121'"
    else
      add_index :fts_tags,
                :name,
                using: "PGroonga",
                with: "normalizer = 'NormalizerNFKC121'"
    end
  end
end
