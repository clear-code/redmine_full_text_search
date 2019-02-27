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
      (attachment_max_text_size_in_mb * 1.megabytes).floor
    end
  end
end
