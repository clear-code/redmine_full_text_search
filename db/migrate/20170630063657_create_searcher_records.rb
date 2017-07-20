class CreateSearcherRecords < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        case
        when Redmine::Database.postgresql?
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
            t.integer :status

            # news
            t.string :title
            t.string :summary
            # t.text :description

            # issues
            t.string :subject
            # t.text :description
            t.integer :author_id
            t.boolean :is_private

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
            # t.integer :user_id # => author_id
            # t.boolean :private_notes # => is_private

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
        when Redmine::Database.mysql?
          create_table :searcher_records, options: "ENGINE=Mroonga" do |t|
            # common
            t.integer :original_id, null: false
            t.string :original_type, null: false
            t.timestamp :original_created_on
            t.timestamp :original_updated_on

            t.integer :project_id, null: false

            # projects
            t.string :name
            t.text :description, limit: 16.megabytes
            t.string :identifier
            t.integer :status

            # news
            t.string :title
            t.string :summary
            # t.text :description

            # issues
            t.string :subject
            # t.text :description
            t.integer :author_id
            t.boolean :is_private

            # documents
            # t.string :title
            # t.text :description

            # changesets
            t.text :comments, limit: 16.megabytes

            # messages
            # t.string :subject
            t.text :content

            # journals
            t.text :notes, limit: 16.megabytes
            # t.integer :user_id # => author_id
            # t.boolean :private_notes # => is_private

            # wiki_pages
            # t.string :title

            # wiki_contents
            t.text :text, limit: 16.megabytes

            # custom_value
            t.text :value, limit: 16.megabytes

            # attachments
            t.string :filename
            # t.text :description

            t.index([:original_id, :original_type], unique: true)
          end
        end
        # Load data
        load_projects(table: "projects",
                      columns:                                %w[name identifier description status],
                      original_columns: %w[created_on updated_on name identifier description status])
        load_data(table: "news",
                  columns:                          %w[title summary description],
                  original_columns: %w[created_on NULL title summary description])
        load_data(table: "issues",
                  columns:                                %w[subject description author_id is_private],
                  original_columns: %w[created_on updated_on subject description author_id is_private])
        load_data(table: "documents",
                  columns:                          %w[title description],
                  original_columns: %w[created_on NULL title description])
        load_data(table: "changesets",
                  columns:                            %w[comments],
                  original_columns: %w[committed_on NULL comments])
        load_data(table: "messages",
                  columns:                                %w[subject content],
                  original_columns: %w[created_on updated_on subject content])
        load_data(table: "journals",
                  columns:                          %w[notes author_id is_private],
                  original_columns: %w[created_on NULL notes user_id private_notes])
        load_data(table: "wiki_pages",
                  columns:                          %w[title],
                  original_columns: %w[created_on NULL title])
        load_data(table: "wiki_contents",
                  columns:                          %w[text],
                  original_columns: %w[NULL updated_on text])
        load_data(table: "custom_values",
                  columns:                    %w[value],
                  original_columns: %w[NULL NULL value],
                  condition: "searchable = true")
        load_attachments(table: "attachments",
                         columns:                          %w[filename description],
                         original_columns: %w[created_on NULL filename description])
      end
      d.down do
        drop_table :searcher_records
      end
    end
  end

  private

  def load_projects(table:, columns:, original_columns:, conditions: "1=1")
    sql = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT id, '#{table.classify}',id, #{original_columns.join(", ")} FROM #{table} AS base
    SQL
    execute(sql)
  end

  def load_data(table:, columns:, original_columns:, condition: "1=1")
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT id, '#{table.classify}', project_id, #{original_columns.join(", ")} FROM #{table} AS base
    SQL
    sql_rest = case table
               when "changesets"
                 %Q[JOIN repositories AS r ON (base.repository_id = r.id)]
               when "messages"
                 %Q[JOIN boards AS b ON (base.board_id = b.id) WHERE]
               when "journals"
                 %Q[JOIN issues i ON (base.journalized_id = i.id) WHERE]
               when "wiki_pages"
                 %Q[JOIN wikis AS w ON (base.wiki_id = w.id)]
               when "wiki_contents"
                 <<-SQL
                 JOIN wiki_pages AS p ON (base.page_id = p.id)
                 JONI wikis AS w ON (p.wiki_id = w.id)
                 SQL
               when "custom_values"
                 <<-SQL
                 JOIN custom_fields AS f ON (base.custom_field_id = f.id)
                 JOIN custom_fields_projects AS p ON (f.id = p.custom_field_id)
                 SQL
               else
                 ""
               end
    sql = "#{sql_base} #{sql_rest} WHERE #{condition};"
    execute(sql)
  end

  def load_attachments(table:, columns:, original_columns:, condition: "1=1")
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT id, '#{table.classify}', project_id, #{original_columns.join(", ")} FROM #{table} AS base
    SQL
    %w(issues documents versions).each do |target|
      sql_rest = %Q[JOIN #{target} AS t ON (base.container_id = t.id)]
      execute("#{sql_base} #{sql_rest} WHERE #{condition};")
    end
    sql_rest = <<-SQL
    JOIN wiki_pages AS p ON (base.container_id = p.id)
    JOIN wikis AS w ON (p.wiki_id = w.id)
    SQL
    execute("#{sql_base} #{sql_rest} WHERE #{condition};")
    sql = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT id, '#{table.classify}', t.id, #{original_columns.join(", ")} FROM #{table} AS base
    JOIN projects AS t ON (base.container_id = t.id) WHERE #{condition};
    SQL
    execute(sql)
  end
end
