require File.expand_path('../../../../test/test_helper', __FILE__)

require "webrick"
require "pp"

module PrettyInspectable
  class << self
    def wrap(object)
      case object
      when Hash
        HashInspector.new(object)
      when Array
        ArrayInspector.new(object)
      else
        object
      end
    end
  end

  class HashInspector
    def initialize(hash)
      @hash = hash
    end

    def inspect
      @hash.inspect
    end

    def pretty_print(q)
      q.group(1, '{', '}') do
        q.seplist(self, nil, :each_pair) do |k, v|
          q.group do
            q.pp(k)
            q.text('=>')
            q.group(1) do
              q.breakable('')
              q.pp(v)
            end
          end
        end
      end
    end

    def pretty_print_cycle(q)
      @hash.pretty_print_cycle(q)
    end

    def each_pair
      keys = @hash.keys
      begin
        keys = keys.sort
      rescue ArgumentError
      end
      keys.each do |key|
        yield(key, PrettyInspectable.wrap(@hash[key]))
      end
    end
  end

  class ArrayInspector
    def initialize(array)
      @array = array
    end

    def inspect
      @array.inspect
    end

    def pretty_print(q)
      q.group(1, '[', ']') do
        q.seplist(self) do |v|
          q.pp(v)
        end
      end
    end

    def pretty_print_cycle(q)
      @array.pretty_print_cycle(q)
    end

    def each(&block)
      @array.each do |element|
        yield(PrettyInspectable.wrap(element))
      end
    end
  end

  def mu_pp(obj)
    PrettyInspectable.wrap(obj).pretty_inspect
  end
end

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
        Time.at(0 - utc_offset - Time.now.utc_offset).in_time_zone
      end
    else
      nil
    end
  end
end

module TimeValue
  include FullTextSearchBackend

  def parse_time(string)
    time = Time.zone.parse(string)
    if mroonga?
      time.change(nsec: 0)
    else
      time
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

  def debug(message=nil)
    @messages << [:debug, message || yield]
  end

  def info(message=nil)
    @messages << [:info, message || yield]
  end

  def error(message=nil)
    @messages << [:error, message || yield]
  end
end
