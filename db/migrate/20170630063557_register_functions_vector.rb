migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class RegisterFunctionsVector < migration
  def change
  end
end
