require "full_text_search/migration"

class CreateIssueContents < ActiveRecord::Migration[4.2]
  def change
    options = nil
    contents_limit = nil
    if Redmine::Database.mysql?
      options = "ENGINE=Mroonga"
      contents_limit = 16.megabytes
    end
    create_table :issue_contents, options: options do |t|
      t.integer :project_id
      t.integer :issue_id, unique: true, null: false
      t.text :subject
      t.text :contents, limit: contents_limit
      t.integer :status_id
      t.boolean :is_private

      if Redmine::Database.mysql?
        t.index :contents,
                type: "fulltext",
                comment: "TOKENIZER 'TokenMecab'"
      else
        t.index [:id,
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
end
