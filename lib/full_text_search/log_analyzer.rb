require "English"
require "optparse"
require "ostruct"
require "json"
require "time"

module FullTextSearch
  class LogAnalyzer
    class Options < Struct.new(:large_memory_usage_diff_threshold,
                               :large_memory_usage_threshold,
                               :slow_elapsed_time_threshold,
                               :report_text_extraction_statistics,
                               :report_search_statistics)
      def report_text_extraction_statistics?
        report_text_extraction_statistics
      end

      def report_search_statistics?
        report_search_statistics
      end
    end

    class Size
      include Comparable

      def initialize(value)
        value = parse(value) if value.is_a?(String)
        @value = value
      end

      def <=>(other)
        to_f <=> other.to_f
      end

      def to_f
        @value
      end

      def to_s
        if @value < 1024
          "%d" % @value
        elsif @value < (1024 * 1024)
          "%.2fKiB" % (@value / 1024.0)
        elsif @value < (1024 * 1024 * 1024)
          "%.2fMiB" % (@value / 1024.0 / 1024.0)
        else
          "%.2fGiB" % (@value / 1024.0 / 1024.0 / 1024.0)
        end
      end

      private
      def parse(value)
        case value
        when /\A([-\d.]+)B?\z/
          Float($1)
        when /\A([-\d.]+)KB?\z/
          Float($1) * 1000
        when /\A([-\d.]+)KiB?\z/
          Float($1) * 1024
        when /\A([-\d.]+)MB?\z/
          Float($1) * 1000 * 1000
        when /\A([-\d.]+)MiB?\z/
          Float($1) * 1024 * 1024
        when /\A([-\d.]+)GB?\z/
          Float($1) * 1000 * 1000 * 1000
        when /\A([-\d.]+)GiB?\z/
          Float($1) * 1024 * 1024 * 1024
        else
          raise "invalid size: <#{value}>"
        end
      end
    end

    class ElapsedTime
      include Comparable

      def initialize(value)
        value = parse(value) if value.is_a?(String)
        @value = value
      end

      def <=>(other)
        to_f <=> other.to_f
      end

      def +(other)
        self.class.new(to_f + other.to_f)
      end

      def -(other)
        self.class.new(to_f - other.to_f)
      end

      def /(other)
        self.class.new(to_f / other.to_f)
      end

      def to_f
        @value
      end

      def to_s
        if @value < 1
          "%.2fms" % (@value * 1000.0)
        elsif @value < 60
          "%.2fs" % @value
        elsif @value < (60 * 60)
          "%.2fm" % (@value / 60.0)
        else
          "%.2fh" % (@value / 60.0 / 60.0)
        end
      end

      private
      def parse(value)
        case value
        when /\A([-\d.]+)ms\z/
          Float($1) / 1000
        when /\A([-\d.]+)s?\z/
          Float($1)
        when /\A([-\d.]+)m\z/
          Float($1) * 60
        when /\A([-\d.]+)h\z/
          Float($1) * 60 * 60
        else
          raise "invalid size: <#{value}>"
        end
      end
    end

    class Record
      attr_reader :label
      def initialize(label, attributes, options)
        @label = label
        @attributes = attributes
        @options = options
      end

      def path
        @attributes["path"]
      end

      def full_text_search_target
        @attributes["FullTextSearch::Target"]
      end

      def repository
        @attributes["Repository"]
      end

      def memory_usage
        Size.new(@attributes["memory usage"] || 0.0)
      end

      def memory_usage_diff
        Size.new(@attributes["memory usage diff"] || 0.0)
      end

      def elapsed_time
        ElapsedTime.new(@attributes["elapsed time"] || 0)
      end

      def large_memory_used?
        memory_usage_diff.to_f >= @options.large_memory_usage_diff_threshold.to_f
      end

      def large_memory_using?
        memory_usage.to_f >= @options.large_memory_usage_threshold.to_f
      end

      def slow?
        elapsed_time.to_f >= @options.slow_elapsed_time_threshold.to_f
      end
    end

    class TextExtractionStatistics
      attr_reader :n_records
      attr_reader :n_slow_records
      attr_reader :total
      attr_reader :max
      attr_reader :min
      attr_reader :mean
      def initialize
        @n_records = 0
        @n_slow_records = 0
        @total = ElapsedTime.new(0.0)
        @max = nil
        @min = nil
        @mean = ElapsedTime.new(0.0)
      end

      def add(record)
        @n_records += 1
        @n_slow_records += 1 if record.slow?
        elapsed_time = record.elapsed_time
        @total += elapsed_time
        if @max.nil? or elapsed_time > @max
          @max = elapsed_time
        end
        if @min.nil? or elapsed_time < @min
          @min = elapsed_time
        end
        @mean += ((elapsed_time - @mean) / @n_records)
      end
    end

    class SearchStatistics
      attr_reader :history
      attr_reader :zero_hits
      attr_reader :slow_searches
      attr_reader :n_searches
      attr_reader :n_visits
      attr_reader :max
      attr_reader :min
      attr_reader :mean
      def initialize
        @history = []
        @zero_hits = []
        @slow_searches = []
        @n_searches = 0
        @n_visits = 0
        @max = nil
        @min = nil
        @mean = ElapsedTime.new(0.0)
      end

      def searched(action)
        @n_searches += 1
        elapsed_time = ElapsedTime.new(action["elapsed_time"])
        if @max.nil? or elapsed_time > @max
          @max = elapsed_time
        end
        if @min.nil? or elapsed_time < @min
          @min = elapsed_time
        end
        @mean += ((elapsed_time - @mean) / @n_searches)
        @history << action
        if action["n_hits"].zero?
          @zero_hits << action
        end
        if elapsed_time > 1.0
          @slow_searches << action
        end
      end

      def visited(parameters)
        @n_visits += 1
        @history << parameters
      end

      def conversions
        each_conversions.to_a
      end

      def each_conversions
        return enum_for(__method__) unless block_given?
        next_action_threshold = 30
        good_threshold = 3
        last_timestamp = nil
        last_search_id = nil
        last_search = nil
        last_visit = nil
        @history.each do |data|
          timestamp = data["timestamp"]
          search_id = data["search_id"]
          choose_n = data["search_n"]
          if choose_n
            last_visit = data
          else
            if last_timestamp and
              last_visit and
              search_id != last_search_id and
              timestamp + next_action_threshold > last_timestamp and
              last_visit["search_n"] < good_threshold
              yield(last_search, last_visit)
            end
            last_search = data
            last_visit = nil
          end
          last_timestamp = timestamp
          last_search_id = search_id
        end
        if last_visit and last_visit["search_n"] < good_threshold
          yield(last_search, last_visit)
        end
      end
    end

    def initialize
      @options = Options.new
      @options.large_memory_usage_diff_threshold = Size.new("512MiB")
      @options.large_memory_usage_threshold = Size.new("1GiB")
      @options.slow_elapsed_time_threshold = ElapsedTime.new("5s")
      @options.report_text_extraction_statistics = true
      @options.report_search_statistics = true
      @extension_statistics = {}
      @search_statistics = {}
    end

    def run(argv)
      parser = create_option_parser
      inputs = nil
      begin
        inputs = parser.parse(argv)
      rescue OptionParser::ParseError => error
        $stderr.puts("Failed to parse options: #{error.message}")
        return false
      end

      if inputs.empty?
        analyze($stdin)
      else
        inputs.each do |path|
          File.open(path) do |input|
            analyze(input)
          end
        end
      end
      report
      true
    end

    private
    def create_option_parser
      option_parser = OptionParser.new
      option_parser.on("--no-report-text-extraction-statistics",
                       "Don't report text extraction statistics") do |boolean|
        @options.report_text_extraction_statistics = boolean
      end
      option_parser.on("--no-report-search-statistics",
                       "Don't report search statistics") do |boolean|
        @options.report_search_statistics = boolean
      end
      option_parser.on("--large-memory-usage-diff-threshold=THRESHOLD",
                       Integer,
                       "Use THRESHOLD as the threshold " +
                       "to judge large memory usage diff",
                       "(#{@options.large_memory_usage_diff_threshold})") do |threshold|
        @options.memory_usage_diff_threshold = parse_size(threshold)
      end
      option_parser.on("--large-memory-usage-threshold=THRESHOLD",
                       "Use THRESHOLD as the threshold " +
                       "to judge large memory usage",
                       "(#{@options.large_memory_usage_threshold})") do |threshold|
        @options.large_memory_usage_threshold = parse_size(threshold)
      end
      option_parser.on("--slow-elapsed-time-threshold=THRESHOLD",
                       "Use THRESHOLD as the threshold " +
                       "to judge slow elapsed time",
                       "(#{@options.slow_elapsed_time_threshold})") do |threshold|
        @options.slow_elapsed_time_threshold = parse_time(threshold)
      end
      option_parser
    end

    def parse_record(text)
      label, raw_attributes = text_extract_message.split(": ")
      attributes = {}
      raw_attributes.each_slice(2).each do |key, value|
        attributes[key] = value[/\A<(.+?)>\z/, 1]
      end
      Record.new(label, attributes, @options)
    end

    def parse_action(raw_action)
      action = JSON.parse(raw_action)
      action["timestamp"] = Time.iso8601(action["timestamp"])
      action
    end

    def parse_parameters(raw_parameters)
      # TODO: security risk
      parameters = BasicObject.new.instance_eval(raw_parameters)
      if parameters["search_n"]
        parameters["search_n"] = Integer(parameters["search_n"], 10)
      end
      parameters
    end

    def parse_user(raw_user)
      case raw_user
      when /([a-zA-Z0-9_-]+) \(id=(\d+)\)\z/
        name = $1
        id = $2
        [name, Integer(id, 10)]
      else
        nil
      end
    end

    def analyze(input)
      last_parameters = nil
      last_request_timestamp = nil
      input.each_line do |line|
        line = line.chomp
        original_line = line
        line = line.scrub unless line.valid_encoding?
        line = line.gsub(/\A\[ActiveJob\] \[.+?\] \[.+?\] /, "")
        case line
        when /\A\[full-text-search\]/
          content = $POSTMATCH
          case content
          when /\A\[text-extract\] /
            raw_record = $POSTMATCH
            next unless @options.report_text_extraction_statistics?
            record = parse_record(raw_record)
            case record.label
            when "Extracted"
              extracted(record)
              if record.large_memory_used?
                puts("large-memory-used: %s:%s:%s" % [
                       record.memory_usage_diff,
                       record.full_text_search_target,
                       record.path,
                     ])
              end
              if record.large_memory_using?
                puts("large-memory-using: %s:%s:%s" % [
                       record.memory_usage,
                       record.full_text_search_target,
                       record.path,
                     ])
              end
              if record.slow?
                puts("slow: %s:%s:%s" % [
                       record.elapsed_time,
                       record.full_text_search_target,
                       record.path,
                     ])
              end
            end
          when /\A\[repository-entry\] /
            raw_record = $POSTMATCH
            next unless @options.report_text_extraction_statistics?
            record = parse_record(raw_record)
            if record.slow?
              puts("slow: %s:%s:%s:%s" % [
                     record.elapsed_time,
                     record.repository,
                     record.label,
                     record.path,
                   ])
            end
          when "Failed to extract text"
            next unless @options.report_text_extraction_statistics?
            case components[11]
            when "ChupaText::EncryptedError"
            else
              puts("error: #{line}")
            end
          when /\A\[search\] /
            raw_action = $POSTMATCH
            next unless @options.report_search_statistics?
            action = parse_action(raw_action)
            searched(action)
          end
        when /\AStarted GET ".+?" for [\d.]+ at /
          raw_timestamp = $POSTMATCH
          next unless @options.report_search_statistics?
          last_request_timestamp = Time.parse(raw_timestamp)
        when /\A  Parameters: /
          raw_parameters = $POSTMATCH
          next unless @options.report_search_statistics?
          last_parameters = nil
          parameters = parse_parameters(raw_parameters)
          next unless parameters["search_id"]
          next unless parameters["search_n"]
          last_parameters = parameters
        when /\A  Current user: /
          raw_user = $POSTMATCH
          next unless @options.report_search_statistics?
          next unless last_request_timestamp
          next unless last_parameters
          user_name, user_id = parse_user(raw_user)
          next if user_id.nil?
          last_parameters["user_name"] = user_name
          last_parameters["user_id"] = user_id
          last_parameters["timestamp"] = last_request_timestamp
          visited(last_parameters)
          last_timestamp = nil
          last_parameters = nil
        end
      end
    end

    def extracted(record)
      extension = File.extname(record.path || "").gsub(/\A\./, "")
      return if extension.empty?
      extension = extension.downcase
      @extension_statistics[extension] ||= TextExtractionStatistics.new
      @extension_statistics[extension].add(record)
    end

    def searched(action)
      @search_statistics[action["user_id"]] ||= SearchStatistics.new
      @search_statistics[action["user_id"]].searched(action)
    end

    def visited(parameters)
      statistics = @search_statistics[parameters["user_id"]]
      return if statistics.nil?
      statistics.visited(parameters)
    end

    def report
      if @options.report_text_extraction_statistics?
        report_text_extraction_statistics
      end
      if @options.report_search_statistics?
        report_search_statistics
      end
    end

    def report_text_extraction_statistics
      puts("Text extraction summary:")
      sorted = @extension_statistics.sort_by do |extension, statistics|
        -statistics.total.to_f
      end
      sorted.each_with_index do |(extension, statistics), i|
        puts("  #{i}: #{extension}")
        puts("    N records:      #{statistics.n_records}")
        puts("    N slow records: #{statistics.n_slow_records}")
        puts("    Total:          #{statistics.total}")
        puts("    Max:            #{statistics.max}")
        puts("    Min:            #{statistics.min}")
        puts("    Mean:           #{statistics.mean}")
      end
    end

    def report_search_statistics
      puts("Search summary:")
      puts("  N users: #{@search_statistics.size}")
      sorted = @search_statistics.sort_by do |user_id, statistics|
        -statistics.history.size
      end
      sorted.each_with_index do |(user_id, statistics), i|
        user_name = nil
        statistics.history.each do |data|
          user_name = data["user_name"]
          break if user_name
        end
        puts("  User: #{i}: #{user_name} (#{user_id})")
        puts("    N searches:       #{statistics.n_searches}")
        puts("    N visits:         #{statistics.n_visits}")
        puts("    Max search time:  #{statistics.max}")
        puts("    Min search time:  #{statistics.min}")
        puts("    Mean search time: #{statistics.mean}")

        conversions = statistics.conversions
        puts("    N conversions:    #{conversions.size}")
        conversions.each_with_index do |(action, visit), j|
          query = action["q"]
          n = visit["search_n"]
          puts("      #{j}: #{query}: #{n}")
        end

        zero_hits = statistics.zero_hits
        zero_hit_ratio = "%3.0f%%" % [
          (zero_hits.size.to_f / statistics.n_searches.to_f) * 100
        ]
        puts("    N zero hits:      #{zero_hits.size} (#{zero_hit_ratio})")
        zero_hits.each_with_index do |action, j|
          query = action["q"]
          puts("      #{j}: #{query}")
        end

        slow_searches = statistics.slow_searches.sort_by do |action|
          -action["elapsed_time"]
        end
        slow_ratio = "%3.0f%%" % [
          (slow_searches.size.to_f / statistics.n_searches.to_f) * 100
        ]
        puts("    N slow searches:  #{slow_searches.size} (#{slow_ratio})")
        slow_searches.each_with_index do |action, j|
          elapsed_time = ElapsedTime.new(action["elapsed_time"])
          puts("      #{j}: #{elapsed_time}")
          puts("        Project:      #{action["project_id"] || "all"}")
          puts("        Query:        #{action["q"]}")
          # pp action
        end
        # pp statistics.history
      end
    end
  end
end
