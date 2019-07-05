require "redmine/scm/adapters/git_adapter"
require "redmine/scm/adapters/subversion_adapter"

# TODO: Submit a patch to Redmine

module Redmine
  module Scm
    module Adapters
      class GitAdapter
        def all_file_entries(identifier=nil)
          entries = Entries.new
          identifier ||= "HEAD"
          cmd_args = [
            "ls-tree",
            "-l",
            "-r",
            "--full-tree",
            "#{identifier}:",
          ]
          git_cmd(cmd_args) do |io|
            io.each_line do |line|
              e = line.chomp.to_s
              if e =~ /^\d+\s+(\w+)\s+([0-9a-f]{40})\s+([0-9-]+)\t(.+)$/
                type = $1
                sha  = $2
                size = $3
                full_path = $4.force_encoding(@path_encoding)
                next if type != "blob"
                full_path_utf8 = scm_iconv('UTF-8', @path_encoding, full_path)
                attributes = {
                  :name => full_path_utf8,
                  :path => full_path_utf8,
                  :kind => "file",
                  :size => size.to_i(10),
                  :lastrev => lastrev(full_path, identifier),
                }
                entries << Entry.new(attributes)
              end
            end
          end
          entries.sort_by do |entry|
            entry.path
          end
        rescue ScmCommandAborted
          []
        end
      end

      class SubversionAdapter
        def all_file_entries(identifier=nil)
          prefix = url.gsub(root_url, "")
          prefix = "/#{prefix}" unless prefix.start_with?("/")
          if identifier and identifier.to_i > 0
            identifier = identifier.to_i
          else
            identifier = "HEAD"
          end
          entries = Entries.new
          root = target("")
          cmd = "#{self.class.sq_bin} list --recursive --xml "
          cmd << "--revision #{identifier} "
          cmd << root
          cmd << credentials_string
          shellout(cmd) do |io|
            output = io.read.force_encoding('UTF-8')
            begin
              doc = parse_xml(output)
              each_xml_element(doc['lists']['list'], 'entry') do |entry|
                commit = entry['commit']
                commit_date = commit['date']
                next unless entry['kind'] == 'file'
                name = entry['name']['__content__']
                path = "#{prefix}#{name}"
                author = commit['author']
                revision_attributes = {
                  :identifier => commit['revision'],
                  :time => Time.parse(commit_date['__content__'].to_s).localtime,
                  :author => (commit['author'] || {})['__content__'],
                }
                size = (entry['size'] || {})["__content__"]
                size = size.to_i(10) if size
                attributes = {
                  :name => URI.unescape(path),
                  :path => path,
                  :kind => entry['kind'],
                  :size => size,
                  :lastrev => Revision.new(revision_attributes),
                }
                entries << Entry.new(attributes)
              end
            rescue Exception => e
              logger.error("Error parsing svn output: #{e.message}")
              logger.error("Output was:\n #{output}")
            end
          end
          return [] if $? && $?.exitstatus != 0
          logger.debug("Found #{entries.size} entries in the repository for #{root}") if logger && logger.debug?
          entries.sort_by do |entry|
            entry.path
          end
        end
      end
    end
  end
end
