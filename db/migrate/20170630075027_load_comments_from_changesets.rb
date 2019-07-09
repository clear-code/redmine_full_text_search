migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class LoadCommentsFromChangesets < migration
  def change
  end
end
