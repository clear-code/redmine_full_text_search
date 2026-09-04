require File.expand_path('../../../../test/test_helper', __FILE__)

require "webrick"
require "pp"

module PrettyInspectable
  class << self
    def wrap(object)
      case object
      when Hash
        HashInspector.new(object)
      when Array
        ArrayInspector.new(object)
      else
        object
      end
    end
  end

  class HashInspector
    def initialize(hash)
      @hash = hash
    end

    def inspect
      @hash.inspect
    end

    def pretty_print(q)
      q.group(1, '{', '}') do
        q.seplist(self, nil, :each_pair) do |k, v|
          q.group do
            q.pp(k)
            q.text('=>')
            q.group(1) do
              q.breakable('')
              q.pp(v)
            end
          end
        end
      end
    end

    def pretty_print_cycle(q)
      @hash.pretty_print_cycle(q)
    end

    def each_pair
      keys = @hash.keys
      begin
        keys = keys.sort
      rescue ArgumentError
      end
      keys.each do |key|
        yield(key, PrettyInspectable.wrap(@hash[key]))
      end
    end
  end

  class ArrayInspector
    def initialize(array)
      @array = array
    end

    def inspect
      @array.inspect
    end

    def pretty_print(q)
      q.group(1, '[', ']') do
        q.seplist(self) do |v|
          q.pp(v)
        end
      end
    end

    def pretty_print_cycle(q)
      @array.pretty_print_cycle(q)
    end

    def each(&block)
      @array.each do |element|
        yield(PrettyInspectable.wrap(element))
      end
    end
  end

  def mu_pp(obj)
    PrettyInspectable.wrap(obj).pretty_inspect
  end
end

module FullTextSearchBackend
  def mroonga?
    Redmine::Database.mysql?
  end

  def pgroonga?
    Redmine::Database.postgresql?
  end
end

module NullValues
  include FullTextSearchBackend

  def null_string
    if mroonga?
      ""
    else
      nil
    end
  end

  def null_number
    if mroonga?
      0
    else
      nil
    end
  end

  def null_boolean
    if mroonga?
      false
    else
      nil
    end
  end

  def null_datetime
    nil
  end

  def null_number_array
    if mroonga?
      []
    else
      nil
    end
  end
end

module TimeValue
  include FullTextSearchBackend

  def parse_time(string)
    time = Time.zone.parse(string)
    if mroonga?
      time.change(nsec: 0)
    else
      time
    end
  end
end

class TestLogger
  attr_reader :messages
  def initialize
    @messages = []
  end

  def debug(message=nil)
    @messages << [:debug, message || yield]
  end

  def info(message=nil)
    @messages << [:info, message || yield]
  end

  def error(message=nil)
    @messages << [:error, message || yield]
  end
end

class RepositoryInfo
  def initialize(repository)
    @repository = repository
  end

  def files
    collect_files
  end

  def n_files
    files.size
  end

  private
  def collect_files(path=nil)
    files = []
    @repository.entries(path).each do |entry|
      if entry.is_file?
        files << entry.path
      elsif entry.is_dir?
        files.concat(collect_files(entry.path))
      end
    end
    files
  end
end

module CommandRunner
  def run_command(*args)
    assert(system(*args, out: File::NULL),
           "Command failed: #{args.join(' ')}")
  end
end

module SubversionRepositoryBuilder
  include CommandRunner

  def create_test_repository(dir)
    repository_path = File.join(dir, "repository")
    run_command("svnadmin", "create", repository_path)

    import_path = File.join(dir, "import")
    FileUtils.mkdir_p(import_path)
    File.write(File.join(import_path, "a.txt"), "FILE: a.txt\n")
    File.write(File.join(import_path, "b.txt"), "FILE: b.txt\n")

    repository_url = "file://#{repository_path}"
    run_command("svn", "import",
                import_path, "#{repository_url}/dir",
                "-m", "Add dir/{a.txt,b.txt}")
    repository_url
  end

  def build_move_directory_repository(dir)
    repository_url = create_test_repository(dir)
    run_command("svn", "move",
                "#{repository_url}/dir", "#{repository_url}/renamed",
                "-m", "Move dir to renamed")
    repository_url
  end

  def build_move_directory_twice_repository(dir)
    repository_url = build_move_directory_repository(dir)
    run_command("svn", "move",
                "#{repository_url}/renamed", "#{repository_url}/rerenamed",
                "-m", "Move dir to rerenamed")
    repository_url
  end

  def build_delete_directory_repository(dir)
    repository_url = create_test_repository(dir)
    run_command("svn", "rm",
                "#{repository_url}/dir",
                "-m", "Delete dir")
    repository_url
  end

  def build_copy_directory_repository(dir)
    repository_url = create_test_repository(dir)
    run_command("svn", "copy",
                "#{repository_url}/dir", "#{repository_url}/copied",
                "-m", "Copy dir to copied")
    repository_url
  end

  def build_move_directory_with_deleted_file_repository(dir)
    repository_url = create_test_repository(dir)
    # Checkout to perform both `move` and `rm` in the same commit.
    # (Operations on `repository_url` result in a separate commit for each operation.)
    work_path = File.join(dir, "work")
    run_command("svn", "checkout", repository_url, work_path)
    run_command("svn", "move",
                File.join(work_path, "dir"), File.join(work_path, "renamed"))
    run_command("svn", "rm", File.join(work_path, "renamed", "b.txt"))
    run_command("svn", "commit",
                "-m", "Move dir to renamed and remove b.txt",
                work_path)
    repository_url
  end

  def build_replace_directory_with_add_repository(dir)
    repository_url = create_test_repository(dir)

    work_path = File.join(dir, "work")
    run_command("svn", "checkout", repository_url, work_path)
    run_command("svn", "rm", File.join(work_path, "dir"))
    run_command("svn", "mkdir", File.join(work_path, "dir"))
    File.write(File.join(work_path, "dir", "new.txt"), "FILE: new.txt\n")
    run_command("svn", "add", File.join(work_path, "dir", "new.txt"))
    run_command("svn", "commit",
                "-m", "Replace dir with a new directory",
                work_path)
    repository_url
  end

  def build_replace_directory_with_move_repository(dir)
    repository_url = create_test_repository(dir)

    import_other_path = File.join(dir, "import_other")
    FileUtils.mkdir_p(import_other_path)
    File.write(File.join(import_other_path, "c.txt"), "FILE: c.txt\n")
    run_command("svn", "import",
                import_other_path, "#{repository_url}/other",
                "-m", "Add other/c.txt")

    work_path = File.join(dir, "work")
    run_command("svn", "checkout", repository_url, work_path)
    run_command("svn", "rm", File.join(work_path, "dir"))
    run_command("svn", "move",
                File.join(work_path, "other"), File.join(work_path, "dir"))
    run_command("svn", "commit",
                "-m", "Replace dir with move directory",
                work_path)
    repository_url
  end
end
