class CreateSearcherRecords < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        create_table :searcher_records do |t|
          # common
          t.integer :original_id, null: false
          t.string :original_type, null: false
          t.timestamp :original_created_on
          t.timestamp :original_updated_on

          # projects
          t.string :name
          t.text :description
          t.string :identifier

          # news
          t.string :title
          t.string :summary
          # t.text :description

          # issues
          t.string :subject
          # t.text :description

          # documents
          # t.string :title
          # t.text :description

          # changesets
          t.text :comments

          # messages
          # t.string :subject
          t.text :content

          # journals
          t.text :notes

          # wiki_pages
          # t.string :title

          # wiki_contents
          t.text :text

          # custom_value
          t.text :value

          # attachments
          t.string :filename
          # t.text :description

          t.index([:original_id, :original_type], unique: true)
        end
        # Load data
        load_data(table: "projects",
                  columns: %w[name description identifier],
                  original_columns: %w[created_on updated_on name identifier description])
        load_data(table: "news",
                  columns: %w[title summary description],
                  original_columns: %w[created_on NULL title summary description])
        load_data(table: "issues",
                  columns: %w[subject description],
                  original_columns: %w[created_on updated_on subject description])
        load_data(table: "documents",
                  columns: %w[title description],
                  original_columns: %w[created_on NULL title description])
        load_data(table: "changesets",
                  columns: %w[comments],
                  original_columns: %w[committed_on NULL comments])
        load_data(table: "messages",
                  columns: %w[subject content],
                  original_columns: %w[created_on updated_on subject contet])
        load_data(table: "journals",
                  columns: %w[notes],
                  original_columns: %w[created_on NULL notes])
        load_data(table: "wiki_pages",
                  columns: %w[title],
                  original_columns: %w[created_on NULL title])
        load_data(table: "wiki_contents",
                  columns: %w[text],
                  original_columns: %w[NULL updated_on text])
        load_data(table: "custom_values",
                  columns: %w[value],
                  original_columns: %w[NULL NULL value])
        load_data(table: "attachments",
                  columns: %w[filename description],
                  original_columns: %w[created_on NULL filename description])
      end
      d.down do
        drop_table :searcher_records
      end
    end

    private

    def load_data(table:, columns:, original_columns:)
      sql = <<-SQL
        INSERT INTO searcher_records(original_id, original_type, original_created_on, original_updated_on, #{columns.join(", ")})
        SELECT id, '#{table.classify}', #{original_columns.join(", ")} FROM #{table};
      SQL
      execute(sql)
    end
  end
end
