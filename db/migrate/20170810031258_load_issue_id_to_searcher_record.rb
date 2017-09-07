class LoadIssueIdToSearcherRecord < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        sql = "UPDATE searcher_records SET issue_id = original_id WHERE original_type = 'Issue'"
        execute(sql)
        sql = case
              when Redmine::Database.postgresql?
                "UPDATE searcher_records AS s SET issue_id = j.journalized_id FROM journals AS j WHERE original_id = j.id AND original_type = 'Journal'"
              when Redmine::Database.mysql?
                "update searcher_records as s join journals as j on s.original_id = j.id set s.issue_id = j.journalized_id where s.original_type = 'Journal'"
              end
        execute(sql)
      end
      d.down do
        # Do nothing
      end
    end
  end
end
