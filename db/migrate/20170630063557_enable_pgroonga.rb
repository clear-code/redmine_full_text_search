class EnablePgroonga < ActiveRecord::Migration[4.2]
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
