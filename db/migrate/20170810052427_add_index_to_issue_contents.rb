class AddIndexToIssueContents < ActiveRecord::Migration
  def change
    reversible do |d|
      case
      when Redmine::Database.postgresql?
        opclass = "pgroonga.varchar_full_text_search_ops"
        d.up do
          columns = [
            "id",
            "issue_id",
            "subject #{opclass}",
            "contents"
          ]
          sql = "CREATE INDEX index_issue_contents_pgroonga ON issue_contents USING pgroonga (#{columns.join(',')})"
          execute(sql)
        end
        d.down do
          remove_index(:issue_contents, name: "index_issue_contents_pgroonga")
        end
      when Redmine::Database.mysql?
        d.up do
          add_index(:issue_contents, :contents, type: "fulltext")
        end
        d.down do
          remove_index(:issue_contents, :contents)
        end
      end
    end
  end
end
