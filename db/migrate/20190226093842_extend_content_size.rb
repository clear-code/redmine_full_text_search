migration = ActiveRecord::Migration
migration = migration[5.2] if migration.respond_to?(:[])
class ExtendContentSize < migration
  def change
    reversible do |d|
      if Redmine::Database.mysql?
        d.up do
          change_column(:searcher_records, :content, :text, limit: 2 ** 32 - 1)
        end
        d.down do
          change_column(:searcher_records, :content, :text)
        end
      end
    end
  end
end
