class CopyRecordsToSearcherRecords < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        # Load data
        load_projects(table: "projects",
                      columns:                                %w[name identifier description status],
                      original_columns: %w[created_on updated_on name identifier description status])
        load_data(table: "news",
                  columns:                          %w[title summary description],
                  original_columns: %w[created_on NULL title summary description])
        load_issues(table: "issues",
                    columns:                                %w[tracker_id subject description author_id status_id is_private],
                    original_columns: %w[created_on updated_on tracker_id subject description author_id status_id is_private])
        load_data(table: "documents",
                  columns:                          %w[title description],
                  original_columns: %w[created_on NULL title description])
        load_data(table: "changesets",
                  columns:                            %w[comments],
                  original_columns: %w[committed_on NULL comments])
        load_data(table: "messages",
                  columns:                                %w[subject content],
                  original_columns: %w[created_on updated_on subject content])
        load_journals(table: "journals",
                      columns:                          %w[notes author_id is_private private_notes status_id],
                      original_columns: %w[created_on NULL notes user_id i.is_private private_notes i.status_id])
        load_data(table: "wiki_pages",
                  columns:                          %w[title text],
                  original_columns: %w[created_on NULL title c.text])
        load_custom_values(table: "custom_values",
                           columns:                    %w[value custom_field_id],
                           original_columns: %w[NULL NULL value custom_field_id])
        load_attachments(table: "attachments",
                         columns:                          %w[filename description],
                         original_columns: %w[created_on NULL filename description])
        
      end
      d.down do
        execute("TRUNCATE TABLE searcher_records")
      end
    end
  end

  private

  def load_projects(table:, columns:, original_columns:)
    sql = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}',id, name, #{transform(original_columns)} FROM #{table} AS base
    SQL
    execute(sql)
  end

  def load_data(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.project_id, p.name, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = case table
               when "changesets"
                 %Q[JOIN repositories AS t ON (base.repository_id = t.id)]
               when "messages"
                 %Q[JOIN boards AS t ON (base.board_id = t.id)]
               when "journals"
                 %Q[JOIN issues t ON (base.journalized_id = t.id)]
               when "wiki_pages"
                 <<-SQL
                 JOIN wikis AS t ON (base.wiki_id = t.id)
                 JOIN wiki_contents as c ON (base.id = c.page_id)
                 SQL
               else
                 "JOIN #{table} AS t ON (base.id = t.id)"
               end
    sql = "#{sql_base} #{sql_rest} JOIN projects AS p ON (t.project_id = p.id);"
    execute(sql)
  end

  def load_issues(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, issue_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', project_id, p.name, base.id, #{transform(original_columns)} FROM #{table} AS base
    JOIN projects AS p ON (project_id = p.id)
    SQL
    sql = "#{sql_base};"
    execute(sql)
  end

  def load_journals(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, issue_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', project_id, p.name, base.journalized_id, #{transform(original_columns)} FROM #{table} AS base
    JOIN issues i ON (base.journalized_id = i.id)
    JOIN projects AS p ON (i.project_id = p.id)
    SQL
    sql = "#{sql_base};"
    execute(sql)
  end

  def load_custom_values(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, status_id, is_private, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', r.project_id, p.name, status_id, is_private, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN issues AS i ON (base.customized_id = i.id)
    JOIN custom_fields AS f ON (base.custom_field_id = f.id)
    JOIN custom_fields_projects AS r ON (base.custom_field_id = r.custom_field_id AND r.project_id = i.project_id)
    JOIN projects AS p ON (r.project_id = p.id)
    SQL
    sql = "#{sql_base} #{sql_rest} WHERE searchable = true;"
    execute(sql)

    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', p.id, p.name, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN custom_fields AS f ON (base.custom_field_id = f.id)
    JOIN projects AS p ON (base.customized_id = p.id)
    SQL
    sql = "#{sql_base} #{sql_rest} WHERE searchable = true;"
    execute(sql)
  end

  # container_type: Document, Issue, Message, News, Project, Version, WikiPage
  def load_attachments(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, container_id, container_type, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.id, t.name, container_id, container_type, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN projects AS t ON (base.container_id = t.id AND base.container_type = 'Project')
    SQL
    execute("#{sql_base} #{sql_rest};")

    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, container_id, container_type, status_id, is_private, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.project_id, p.name, container_id, container_type, status_id, is_private, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN issues AS t ON (base.container_id = t.id AND base.container_type = 'Issue')
    JOIN projects AS p ON (t.project_id = p.id)
    SQL
    execute("#{sql_base} #{sql_rest};")

    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, project_name, container_id, container_type, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.project_id, p.name, container_id, container_type, #{transform(original_columns)} FROM #{table} AS base
    SQL
    %w(documents news versions).each do |target|
      sql_rest = <<-SQL
      JOIN #{target} AS t ON (base.container_id = t.id AND base.container_type = '#{target.classify}')
      JOIN projects AS p ON (t.project_id = p.id)
      SQL
      execute("#{sql_base} #{sql_rest};")
    end

    sql_rest = <<-SQL
    JOIN messages AS m ON (base.container_id = m.id AND base.container_type = 'Message')
    JOIN boards AS t ON (m.board_id = t.id)
    JOIN projects AS p ON (t.project_id = p.id)
    SQL
    execute("#{sql_base} #{sql_rest};")

    sql_rest = <<-SQL
    JOIN wiki_pages AS wp ON (base.container_id = wp.id AND base.container_type = 'WikiPage')
    JOIN wikis AS t ON (wp.wiki_id = t.id)
    JOIN projects AS p ON (t.project_id = p.id)
    SQL
    execute("#{sql_base} #{sql_rest};")
  end

  def transform(original_columns, prefix = "base")
    original_columns.map do |c|
      if c == "NULL" || c.include?(".")
        c
      else
        "#{prefix}.#{c}"
      end
    end.join(", ")
  end
end
