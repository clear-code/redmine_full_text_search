require "chupa-text/sax-parser"

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
        class ListListener < ChupaText::SAXListener
          def initialize(path_prefix, entries)
            @path_prefix = path_prefix
            @entries = entries
            @tag_names = []
            @entry_attributes = nil
            @revision_attributes = nil
          end

          def start_element(uri, local_name, qname, attributes)
            @tag_names.push(local_name)
            case local_name
            when "entry"
              @entry_attributes = {
                kind: attributes["kind"],
              }
            when "commit"
              @revision_attributes = {
                identifier: attributes["revision"],
              }
            end
          end

          def end_element(uri, local_name, qname)
            case local_name
            when "entry"
              if @entry_attributes[:kind] == "file"
                @entries << Entry.new(@entry_attributes)
              end
              @entry_attributes = nil
            when "commit"
              @entry_attributes[:lastrev] = Revision.new(@revision_attributes)
              @revision_attributes = nil
            end
            @tag_names.pop
          end

          def characters(text)
            case @tag_names.last
            when "name"
              path = "#{@path_prefix}#{text}"
              @entry_attributes[:name] = URI.unescape(path)
              @entry_attributes[:path] = path
            when "size"
              @entry_attributes[:size] = Integer(text, 10)
            when "author"
              @revision_attributes[:author] = text
            when "date"
              @revision_attributes[:date] = Time.iso8601(text).localtime
            end
          end
        end

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
            listener = ListListener.new(prefix, entries)
            begin
              parser = ChupaText::SAXParser.new(io, listener)
              parser.parse
            rescue ChupaText::SAXParser::ParseError => e
              logger.error("Error parsing svn output: #{e.message}")
              logger.error(e.backtrace.join("\n"))
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
