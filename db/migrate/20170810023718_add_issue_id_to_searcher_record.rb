class AddIssueIdToSearcherRecord < ActiveRecord::Migration
  def change
    add_column(:searcher_records, :issue_id, :integer)
  end
end
