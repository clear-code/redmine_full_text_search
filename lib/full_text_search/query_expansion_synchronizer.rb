module FullTextSearch
  class QueryExpansionSynchronizer
    def initialize(input)
      @input = input
    end

    def synchronize
      start = Time.current - 1
      each_record do |record|
        attributes = {
          source: record["source"],
          destination: record["destination"],
        }
        query_expansion = FtsQueryExpansion.find_or_initialize_by(attributes)
        query_expansion.updated_at = Time.current
        unless query_expansion.save
          Rails.logger.warn("#{log_tag} failed to save:")
          query_expansion.errors.full_messages.each do |message|
            Rails.logger.warn("#{log_tag}   #{message}")
          end
        end
      end
      not_updated = FtsQueryExpansion.where("updated_at < ?", start)
      not_updated.destroy_all
    end

    private
    BOM_CODE_POINT = 0xfeff
    def open_input
      if @input.respond_to?(:getc)
        yield(@input)
      else
        File.open(@input) do |input|
          yield(input)
        end
      end
    end

    def each_record
      open_input do |input|
        skip_bom(input)
        case detect_format(input)
        when :json
          JSON.parse(input.read).each do |row|
            if row.is_a?(Array)
              record = {
                "source" => row[0],
                "destination" => row[1],
              }
            else
              record = row
            end
            yield(record)
          end
        else
          csv = CSV.new(input)
          csv.each do |row|
            record = {
              "source" => row[0],
              "destination" => row[1],
            }
            yield(record)
          end
        end
      end
    end

    def skip_bom(input)
      first_character = input.getc
      unless first_character.codepoints[0] == BOM_CODE_POINT
        input.ungetc(first_character)
      end
    end

    def detect_format(input)
      if input.respond_to?(:path)
        case input.path
        when /\.json\z/i
          :json
        when /\.csv\z/i
          :csv
        else
          nil
        end
      else
        first_character = input.getc
        input.ungetc(first_character)
        case first_character
        when "["
          :json
        else
          nil
        end
      end
    end

    def log_tag
      "[full-text-search][query-expansion][synchronize]"
    end
  end
end
