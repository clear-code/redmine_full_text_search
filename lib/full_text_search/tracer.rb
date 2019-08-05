module FullTextSearch
  class Tracer
    def initialize(tag)
      @tag = tag
      @start_memory_usage = compute_memory_usage
      @start_time = Time.now
    end

    def trace(log_level, label, data, error: nil)
      Rails.logger.__send__(log_level) do
        format_message(label, data, error)
      end
    end

    private
    def compute_memory_usage
      status_path = "/proc/self/status"
      if File.exist?(status_path)
        File.open(status_path) do |status|
          status.each_line do |line|
            case line
            when /\AVmRSS:\s+(\d+) kB/
              return Integer($1, 10) * 1024
            end
          end
        end
      end
      0
    end

    def format_message(label, data, error)
      message = "[full-text-search]#{@tag} #{label}"
      data.each do |data_label, data_value|
        message << ": #{data_label}: <#{data_value}>"
      end
      elapsed_time = Time.now - @start_time
      message << ": elapsed time: <#{format_elapsed_time(elapsed_time)}>"
      memory_usage = compute_memory_usage
      if memory_usage > 0
        message << ": memory usage: <#{format_memory_usage(memory_usage)}>"
        memory_usage_diff = memory_usage - @start_memory_usage
        message <<
          ": memory usage diff: <#{format_memory_usage(memory_usage_diff)}>"
      end
      if error
        message << ": #{error.class}: #{error.message}\n"
        message << error.backtrace.join("\n")
      end
      message
    end

    def format_elapsed_time(elapsed_time)
      if elapsed_time < 1
        "%.2fms" % (elapsed_time * 1000)
      elsif elapsed_time < 60
        "%.2fs" % elapsed_time
      elsif elapsed_time < (60 * 60)
        "%.2fm" % (elapsed_time / 60)
      else
        "%.2fh" % (elapsed_time / 60 / 60)
      end
    end

    def format_memory_usage(memory_usage)
      if memory_usage < (1024.0 * 1024.0 * 1024.0)
        "%.2fMiB" % (memory_usage / 1024.0 / 1024.0)
      else
        "%.2fGiB" % (memory_usage / 1024.0 / 1024.0 / 1024.0)
      end
    end
  end
end
