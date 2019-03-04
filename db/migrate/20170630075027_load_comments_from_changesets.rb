migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class LoadCommentsFromChangesets < migration
  def change
    reversible do |d|
      d.up do
      end
      d.down do
      end
    end
  end
end
