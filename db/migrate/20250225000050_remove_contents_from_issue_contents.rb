# For auto load
FullTextSearch::Migration

class RemoveContentsFromIssueContents < ActiveRecord::Migration[5.2]
  if Redmine::Database.mysql?
    include FullTextSearch::Mroonga
  else
    include FullTextSearch::Pgroonga
  end

  def up
    return unless table_exists?(:issue_contents)

    if Redmine::Database.mysql?
      remove_index :issue_contents, :contents
    else
      remove_index :issue_contents, name: "index_issue_contents_pgroonga"
    end
    remove_column :issue_contents, :contents, :text
    remove_column :issue_contents, :is_private, :boolean
    content_limit = Redmine::Database.mysql? ? 16.megabytes : nil
    add_column :issue_contents, :content, :text, limit: content_limit

    # TODO: Replace 'TokenMecab' with a multilingual morphological based tokenizer
    # when available. See also: groonga/groonga#1941.
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
                  "normalizer = '#{normalizer}'",
                ].join(", ")
    end
  end

  def down
    return unless table_exists?(:issue_contents)

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
                  "normalizer = '#{normalizer}'",
                ].join(", ")
    end
  end

  private

  def normalizer
    version = Gem::Version.new(self.class.groonga_version)
    if version >= Gem::Version.new("14.1.3")
      "NormalizerNFKC"
    elsif version >= Gem::Version.new("13.0.0")
      "NormalizerNFKC150"
    elsif version >= Gem::Version.new("10.0.9")
      "NormalizerNFKC130"
    else
      "NormalizerNFKC121"
    end
  end
end
