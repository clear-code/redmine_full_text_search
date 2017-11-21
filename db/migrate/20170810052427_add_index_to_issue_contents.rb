class AddIndexToIssueContents < ActiveRecord::Migration
  def change
    reversible do |d|
      case
      when Redmine::Database.postgresql?
        opclass = "pgroonga_varchar_full_text_search_ops_v2"
        d.up do
          columns = [
            "id",
            "project_id",
            "issue_id",
            "subject #{opclass}",
            "contents",
            "status_id",
            "is_private"
          ]
          sql = "CREATE INDEX index_issue_contents_pgroonga ON issue_contents USING pgroonga (#{columns.join(',')}) WITH (tokenizer = 'TokenMecab')"
          execute(sql)
        end
        d.down do
          remove_index(:issue_contents, name: "index_issue_contents_pgroonga")
        end
      when Redmine::Database.mysql?
        d.up do
          # Support comment option since AR5
          # add_index(:issue_contents, :contents, type: "fulltext", comment: 'tokenizer "TokenMecab"')
          sql = "CREATE FULLTEXT INDEX index_issue_contents_on_contents ON issue_contents(contents) COMMENT 'tokenizer \"TokenMecab\"'"
          execute(sql)
        end
        d.down do
          remove_index(:issue_contents, :contents)
        end
      end
    end
  end
end
