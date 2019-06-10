module FullTextSearch
  module SettingsObjectize
    def plugin_full_text_search
      Settings.new(super)
    end
  end

  class Settings
    TRUE_VALUE = "1"

    def initialize(raw)
      @raw = raw || {}
    end

    def display_score?
      @raw["display_score"] == TRUE_VALUE
    end

    DEFAULT_ATTACHMENT_MAX_TEXT_SIZE_IN_MB = 4
    def attachment_max_text_size_in_mb
      size = @raw.fetch("attachment_max_text_size_in_mb",
                        DEFAULT_ATTACHMENT_MAX_TEXT_SIZE_IN_MB)
      begin
        Float(size)
      rescue ArgumentError
        DEFAULT_ATTACHMENT_MAX_TEXT_SIZE_IN_MB
      end
    end

    def attachment_max_text_size
      size = (attachment_max_text_size_in_mb * 1.megabytes).floor
      if Redmine::Database.mysql?
        connection = ActiveRecord::Base.connection
        result = connection.exec_query("SELECT @@max_allowed_packet",
                                       "max allowed package")
        max_allowed_packet = result[0]["@@max_allowed_packet"]
        [size, (max_allowed_packet * 0.7).floor].min
      else
        size
      end
    end

    DEFAULT_EXTERNAL_COMMAND_TIMEOUT = 180
    def external_command_timeout
      timeout = @raw.fetch("external_command_timeout",
                           DEFAULT_EXTERNAL_COMMAND_TIMEOUT)
      begin
        Float(timeout)
      rescue ArgumentError
        DEFAULT_EXTERNAL_COMMAND_TIMEOUT
      end
    end

    external_command_max_memory_in_mb = 1024
    if File.readable?("/proc/meminfo")
      File.open("/proc/meminfo") do |meminfo|
        meminfo.each_line do |line|
          case line
          when /\AMemTotal:\s+(\d+) kB/
            total_memory = Integer($1, 10)
            external_command_max_memory_in_mb =
              ((total_memory / 4) / 1024.0).round
            break
          end
        end
      end
    end
    DEFAULT_EXTERNAL_COMMAND_MAX_MEMORY_IN_MB = external_command_max_memory_in_mb
    def external_command_max_memory_in_mb
      size = @raw.fetch("external_command_max_memory_in_mb",
                        DEFAULT_EXTERNAL_COMMAND_MAX_MEMORY_IN_MB)
      begin
        Float(size)
      rescue ArgumentError
        DEFAULT_EXTERNAL_COMMAND_MAX_MEMORY_IN_MB
      end
    end

    def external_command_max_memory
      (external_command_max_memory_in_mb * 1.megabytes).floor
    end

    def server_url
      @raw["server_url"].presence
    end
  end
end
