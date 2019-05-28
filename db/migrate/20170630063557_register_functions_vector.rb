migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class RegisterFunctionsVector < migration
  def change
    reversible do |d|
      d.up do
        if Redmine::Database.postgresql?
          enable_extension("pgroonga") unless extension_enabled?("pgroonga")
        end
      end
    end
  end
end
