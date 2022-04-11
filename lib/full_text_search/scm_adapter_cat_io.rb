# For auto load
Redmine::Scm::Adapters::GitAdapter
Redmine::Scm::Adapters::SubversionAdapter

# TODO: Submit a patch to Redmine

module Redmine
  module Scm
    module Adapters
      class GitAdapter
        def cat_io(path, identifier=nil)
          if identifier.nil?
            identifier = 'HEAD'
          end
          cmd_args = %w|show --no-color|
          cmd_args << "#{identifier}:#{scm_iconv(@path_encoding, 'UTF-8', path)}"
          cat = nil
          git_cmd(cmd_args) do |io|
            io.binmode
            yield(io)
          end
        rescue ScmCommandAborted
        end
      end

      class SubversionAdapter
        def cat_io(path, identifier=nil)
          identifier = (identifier and identifier.to_i > 0) ? identifier.to_i : "HEAD"
          cmd = "#{self.class.sq_bin} cat #{target(path)}@#{identifier}"
          cmd << credentials_string
          cat = nil
          shellout(cmd) do |io|
            io.binmode
            yield(io)
          end
        end
      end
    end
  end
end

# For auto load
module FullTextSearch
  module ScmAdapterCatIo
  end
end
