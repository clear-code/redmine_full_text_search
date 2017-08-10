class LoadIssueIdToSearcherRecord < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        sql = "UPDATE searcher_records SET issue_id = original_id WHERE original_type = 'Issue'"
        execute(sql)
        # Following query on PostgreSQL causes error, so I decided to update searcher_records using AR
        # sql = "UPDATE searcher_records AS s SET issue_id = j.journalized_id FROM journals AS j WHERE original_id = j.id AND original_type = 'Journal'"
        # execute(sql)
        n_records = Journal.count(:id)
        n_pages = n_records / 1000
        (0..n_pages).each do |offset|
          Journal.limit(1000).offset(offset * 1000).each do |record|
            FullTextSearch::SearcherRecord
              .where(original_id: record.id, original_type: "Journal")
              .update_all(issue_id: record.journalized_id)
          end
        end
      end
      d.down do
        # Do nothing
      end
    end
  end
end
