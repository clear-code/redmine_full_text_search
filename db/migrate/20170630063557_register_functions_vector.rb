class RegisterFunctionsVector < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        command = "plugin_register functions/vector"
        case
        when Redmine::Database.postgresql?
          execute("select pgroonga_command('#{command}')")
        when Redmine::Database.mysql?
          execute("select mroonga_command('#{command}')")
        else
          # do nothing
        end
      end
      d.down do
        command = "plugin_unregister functions/vector"
        case
        when Redmine::Database.postgresql?
          execute("select pgroonga_command('#{command}')")
        when Redmine::Database.mysql?
          execute("select mroonga_command('#{command}')")
        else
          # do nothing
        end
      end
    end
  end
end
