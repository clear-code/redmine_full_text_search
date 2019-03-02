ChupaText.logger = Rails.logger
ChupaText::Decomposers.enable_all_gems
ChupaText::Decomposers.load
ChupaText::Configuration.default
ENV["CHUPA_TEXT_EXTERNAL_COMMAND_LIMIT_CPU"] ||= "180"
if File.readable?("/proc/meminfo")
  File.open("/proc/meminfo") do |meminfo|
    meminfo.each_line do |line|
      case line
      when /\AMemTotal:\s+(\d+) kB/
        total_memory = Integer($1, 10)
        ENV["CHUPA_TEXT_EXTERNAL_COMMAND_LIMIT_AS"] ||= "#{total_memory / 4}KB"
        break
      end
    end
  end
end
