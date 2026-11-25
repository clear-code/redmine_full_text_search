module FullTextSearch
  module SettingsObjectize
    def plugin_full_text_search
      Settings.new(super)
    end
  end

  class Settings
    TRUE_VALUE = "1"
    FALSE_VALUE = "0"

    def initialize(raw)
      @raw = raw || {}
    end

    def with_indifferent_access
      @raw.with_indifferent_access
    end

    def to_h
      @raw.to_h
    end

    def to_hash
      @raw.to_h
    end

    def display_score?
      @raw["display_score"] == TRUE_VALUE
    end

    def display_similar_issues?
      @raw["display_similar_issues"] == TRUE_VALUE
    end

    def enable_tracking?
      @raw["enable_tracking"] != FALSE_VALUE
    end

    def enable_fuzzy_search?
      @raw["enable_fuzzy_search"] == TRUE_VALUE
    end

    DEFAULT_FUZZY_MAX_DISTANCE_RATIO = 0.34
    def fuzzy_max_distance_ratio
      ratio = @raw.fetch("fuzzy_max_distance_ratio", DEFAULT_FUZZY_MAX_DISTANCE_RATIO)
      begin
        Float(ratio)
      rescue ArgumentError
        DEFAULT_FUZZY_MAX_DISTANCE_RATIO
      end
    end

    def enable_periodic_synchronization?
      @raw["enable_periodic_synchronization"] == TRUE_VALUE
    end

    DEFAULT_SYNCHRONIZATION_INTERVAL = "daily"
    def synchronization_interval
      interval = @raw["synchronization_interval"].presence || DEFAULT_SYNCHRONIZATION_INTERVAL
      interval
    end

    def synchronization_cron
      case synchronization_interval
      when "hourly"
        "0 * * * *"
      when "every_6_hours"
        "0 */6 * * *"
      when "daily"
        "0 2 * * *"
      when "weekly"
        "0 2 * * 0"
      else
        @raw["synchronization_custom_cron"].presence || "0 2 * * *"
      end
    end

    def enable_semantic_search?
      @raw["enable_semantic_search"] == TRUE_VALUE
    end

    def semantic_model
      @raw["semantic_model"].presence
    end

    def semantic_passage_prefix
      @raw["semantic_passage_prefix"].presence
    end

    def semantic_query_prefix
      @raw["semantic_query_prefix"].presence
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

    DEFAULT_TEXT_EXTRACTION_TIMEOUT = 180
    def text_extraction_timeout
      timeout = @raw.fetch("text_extraction_timeout",
                           DEFAULT_TEXT_EXTRACTION_TIMEOUT)
      begin
        Float(timeout)
      rescue ArgumentError
        DEFAULT_TEXT_EXTRACTION_TIMEOUT
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

    DEFAULT_N_WORKERS = 0
    def n_workers
      n_workers = @raw.fetch("n_workers", DEFAULT_N_WORKERS)
      begin
        Integer(n_workers.to_s, 10)
      rescue ArgumentError
        DEFAULT_N_WORKERS
      end
    end
  end
end
