module FullTextSearch
  class RepositoryEntry
    attr_reader :path
    def initialize(repository, path, identifier)
      @repository = repository
      @path = path
      @identifier = identifier
      @entry = fetch_entry
    end

    def exist?
      not @entry.nil?
    end

    def file?
      @entry and @entry.is_file?
    end

    def directory?
      @entry and @entry.is_dir?
    end

    def cat(&block)
      trace("Fetched content") do
        @repository.scm.cat_io(@path, @identifier, &block)
      end
    end

    private
    def fetch_entry
      trace("Fetched an entry") do
        relative_path = @repository.relative_path(@path)
        parts = relative_path.to_s.split(%r{[\/\\]}).select {|n| !n.blank?}
        search_path = parts[0..-2].join('/')
        search_name = parts[-1]
        if search_path.blank? and search_name.blank?
          @repository.entry(relative_path, @identifier)
        else
          entries = fetch_entries(search_path)
          entries&.detect {|entry| entry.name == search_name}
        end
      end
    end

    @@cache_mutex = Mutex.new
    @@cached_entries = {}
    def fetch_entries(path)
      trace("Fetched entries") do
        cache_key = [@repository.id, path, @identifier]
        @@cache_mutex.synchronize do
          @@cached_entries[cache_key] ||=
            @repository.scm.entries(path, @identifier)
        end
      end
    end

    def trace(label)
      tracer = Tracer.new("[repository-entry]")
      tracer_data = [
        ["Repository", @repository.id],
        ["path", @path],
        ["identifier", @identifier],
      ]
      begin
        yield
      ensure
        tracer.trace(:info, label, tracer_data)
      end
    end
  end
end
