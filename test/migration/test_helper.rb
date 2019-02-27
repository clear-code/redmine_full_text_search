require "json"
require "tempfile"

module MigrationHelper
  def rails_major_version
    File.open("Gemfile") do |gemfile|
      gemfile.each_line do |line|
        return Integer($1, 10) if /\Agem "rails", "(\d+)\./ =~ line
      end
    end
  end

  def task_runner
    if rails_major_version == 4
      "bin/rake"
    else
      "bin/rails"
    end
  end

  def run_task(*arguments)
    assert do
      system(task_runner, *arguments)
    end
  end

  def run_script(script)
    output = Tempfile.new("output")
    assert do
      system("bin/rails", "runner", script, out: output)
    end
    output.rewind
    output.read
  end

  def setup_db
    run_task("db:drop")
    run_task("db:create")
    run_task("db:migrate", out: File::NULL)
    run_task("redmine:load_default_data", "REDMINE_LANG=en", out: File::NULL)
    run_task("redmine:plugins:migrate", out: File::NULL)
  end

  def create_record(record_class, attributes)
    run_script("#{record_class}.create!(" +
               "JSON.parse(#{attributes.to_json.dump})" +
               ")")
  end

  def indexed_types
    script = "FullTextSearch::SearcherRecord.all.pluck(:original_type)"
    json = run_script("puts(#{script}.to_json)")
    JSON.parse(json)
  end

  def migrate(version: nil)
    stdout_file = Tempfile.new("stdout")
    stderr_file = Tempfile.new("stderr")
    command_line = [
      task_runner,
      "redmine:plugins:migrate",
      "NAME=full_text_search",
    ]
    command_line << "VERSION=#{version}" if version
    success = system(*command_line,
                     out: stdout_file,
                     err: stderr_file)
    stdout_file.rewind
    stderr_file.rewind
    stdout = stdout_file.read
    stderr = stderr_file.read
    unless success
      message = "Failed to "
      if version == 0
        message << "rollback"
      else
        version_label = version || "latest"
        message << "migrate to #{version_label}"
      end
      message << "\n"
      message << "stdout:\n"
      message << stdout
      message << "stderr:\n"
      message << stderr
      raise message
    end
    [stdout, stderr]
  end

  def remigrate
    migrate(version: 0)
    migrate
  end
end
