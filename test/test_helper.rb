require File.expand_path('../../../../test/test_helper', __FILE__)

module FullTextSearchBackend
  def mroonga?
    Redmine::Database.mysql?
  end

  def pgroonga?
    Redmine::Database.postgresql?
  end
end

module NullValues
  include FullTextSearchBackend

  def null_string
    if mroonga?
      ""
    else
      nil
    end
  end

  def null_number
    if mroonga?
      0
    else
      nil
    end
  end

  def null_boolean
    if mroonga?
      false
    else
      nil
    end
  end

  def null_datetime
    if mroonga?
      if Rails::VERSION::MAJOR >= 5
        nil
      else
        connection = ActiveRecord::Base.connection
        db_time_zone =
          connection.execute("SHOW VARIABLES LIKE 'time_zone'").first[1]
        if db_time_zone == "SYSTEM"
          db_time_zone =
            connection.execute("SHOW VARIABLES LIKE 'system_time_zone'").first[1]
        end
        utc_offset = 0
        TZInfo::Timezone.all.each do |zone|
          period = zone.current_period
          if period.abbreviation == db_time_zone.to_sym
            utc_offset = period.offset.utc_offset
            break
          end
        end
        Time.at(0 - utc_offset).in_time_zone
      end
    else
      nil
    end
  end
end

module GroongaCommandExecutable
  include FullTextSearchBackend

  def execute_groonga_command(*args)
    if mroonga?
      function = "mroonga_command"
    else
      function = "pgroonga_command"
    end
    connection = ActiveRecord::Base.connection
    sql = ActiveRecord::Base.__send__(:sanitize_sql_array,
                                      ["SELECT #{function}(?)", args])
    connection.select_one(sql)
  end
end

class TestLogger
  attr_reader :messages
  def initialize
    @messages = []
  end

  def info(message=nil)
    @messages << [:info, message || yield]
  end

  def error(message=nil)
    @messages << [:error, message || yield]
  end
end
