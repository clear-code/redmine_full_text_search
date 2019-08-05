require "English"
require "optparse"
require "ostruct"

module FullTextSearch
  class LogAnalyzer
    class Options < Struct.new(:large_memory_usage_diff_threshold,
                               :large_memory_usage_threshold,
                               :slow_elapsed_time_threshold)
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

    class Statistics
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

    def initialize
      @options = Options.new
      @options.large_memory_usage_diff_threshold = Size.new("512MiB")
      @options.large_memory_usage_threshold = Size.new("1GiB")
      @options.slow_elapsed_time_threshold = ElapsedTime.new("5s")
      @extension_statistics = {}
    end

    def run(argv)
      parser = create_option_parser
      inputs = nil
      begin
        inputs = parser.parse(argv)
      rescue OptionParser::Error => error
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

    def analyze(input)
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
            record = parse_record($POSTMATCH)
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
            record = parse_record($POSTMATCH)
            if record.slow?
              puts("slow: %s:%s:%s:%s" % [
                     record.elapsed_time,
                     record.repository,
                     record.label,
                     record.path,
                   ])
            end
          when "Failed to extract text"
            case components[11]
            when "ChupaText::EncryptedError"
            else
              puts("error: #{line}")
            end
          end
        end
      end
    end

    def extracted(record)
      extension = File.extname(record.path || "").gsub(/\A\./, "")
      return if extension.empty?
      extension = extension.downcase
      @extension_statistics[extension] ||= Statistics.new
      @extension_statistics[extension].add(record)
    end

    def report
      puts("Summary:")
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
  end
end
