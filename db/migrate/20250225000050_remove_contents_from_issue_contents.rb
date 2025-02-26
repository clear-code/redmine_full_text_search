# For auto load
FullTextSearch::Migration

class RemoveContentsFromIssueContents < ActiveRecord::Migration[5.2]
  def up
    return if !table_exists?(:issue_contents)

    if Redmine::Database.mysql?
      remove_index :issue_contents, :contents
    else
      remove_index :issue_contents, name: "index_issue_contents_pgroonga"
    end
    remove_column :issue_contents, :contents, :text
    remove_column :issue_contents, :is_private, :boolean
    contents_limit = Redmine::Database.mysql? ? 16.megabytes : nil
    add_column :issue_contents, :content, :text, limit: contents_limit

    if Redmine::Database.mysql?
      add_index :issue_contents,
                :content,
                type: "fulltext",
                comment: "TOKENIZER 'TokenMecab'"
    else
      add_index :issue_contents,
                [:id,
                 :project_id,
                 :issue_id,
                 :subject,
                 :content,
                 :status_id],
                name: "index_issue_contents_pgroonga",
                using: "PGroonga",
                with: [
                  "tokenizer = 'TokenMecab'",
                  "normalizer = 'NormalizerNFKC121'",
                ].join(", ")
    end
  end

  def down
    return if !table_exists?(:issue_contents)

    if Redmine::Database.mysql?
      remove_index :issue_contents, :content
    else
      remove_index :issue_contents, name: "index_issue_contents_pgroonga"
    end
    remove_column :issue_contents, :content, :text
    contents_limit = Redmine::Database.mysql? ? 16.megabytes : nil
    add_column :issue_contents, :contents, :text, limit: contents_limit
    add_column :issue_contents, :is_private, :boolean
    if Redmine::Database.mysql?
      add_index :issue_contents,
                :contents,
                type: "fulltext",
                comment: "TOKENIZER 'TokenMecab'"
    else
      add_index :issue_contents,
                [:id,
                 :project_id,
                 :issue_id,
                 :subject,
                 :contents,
                 :status_id,
                 :is_private],
                name: "index_issue_contents_pgroonga",
                using: "PGroonga",
                with: [
                  "tokenizer = 'TokenMecab'",
                  "normalizer = 'NormalizerNFKC121'",
                ].join(", ")
    end
  end
end
