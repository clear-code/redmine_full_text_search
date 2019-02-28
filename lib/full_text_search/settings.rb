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
        [size, (max_allowed_packet * 0.9).floor].min
      else
        size
      end
    end
  end
end
