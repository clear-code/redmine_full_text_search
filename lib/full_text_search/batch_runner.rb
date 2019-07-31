module FullTextSearch
  class BatchRunner
    def initialize(show_progress: false)
      @show_progress = show_progress
    end

    def synchronize(project: nil,
                    upsert: nil,
                    extract_text: nil)
      options = Options.new(project, upsert, extract_text)
      synchronize_fts_targets_internal(options)
    end

    def synchronize_fts_targets(project: nil,
                                upsert: nil,
                                extract_text: nil)
      options = Options.new(project, upsert, extract_text)
      synchronize_fts_targets_internal(options)
    end

    def synchronize_repositories(project: nil,
                                 upsert: nil,
                                 extract_text: nil)
      options = Options.new(project, upsert, extract_text)
      synchronize_repositories_internal(options)
    end

    def reload_fts_targets(project: nil,
                           upsert: nil,
                           extract_text: nil)
      options = Options.new(project, upsert, extract_text)
      if options.project
        targets = Target.where(project_id: options.project.id)
      else
        targets = Target.all
      end
      bar = create_progress_bar("FullTextSearch::Target",
                                total: targets.count)
      bar.start
      each_target = targets.select(:id, :source_id, :source_type_id).find_each
      resolver = FullTextSearch.resolver
      bar.iterate(each_target) do |target|
        mapper_class = resolver.resolve(Type.find(target.source_type_id).name)
        if options.upsert == :later
          UpsertTargetJob
            .set(priority: UpsertTargetJob.priority + 1)
            .perform_later(mapper_class.name, target.source_id)
        else
          source_record = target.source_record
          mapper = mapper_class.redmine_mapper(source_record)
          mapper.upsert_fts_target(extract_text: options.extract_text)
        end
      end
      bar.finish
    end

    def extract_text(ids: nil)
      attachments = Target.where(source_type_id: Type.attachment.id)
      attachments = attachments.where(id: ids) if ids
      bar = create_progress_bar("Extract",
                                total: attachments.count)
      attachments.find_each do |record|
        record.mapper.redmine_mapper.extract_text
        bar.advance
      end
      bar.finish
    end

    private
    def synchronize_fts_targets_internal(options)
      all_bar = create_multi_progress_bar("FullTextSearch::Target:All")
      bars = {}

      resolver = FullTextSearch.resolver
      resolver.each do |redmine_class, mapper_class|
        new_redmine_records =
          mapper_class.not_mapped_redmine_records(project: options.project)
        label = "#{redmine_class.name}:New"
        bars[label] =
          create_sub_progress_bar(all_bar,
                                  label,
                                  total: new_redmine_records.count)

        orphan_fts_targets = mapper_class.orphan_fts_targets
        label = "#{redmine_class.name}:Orphan"
        bars[label] =
          create_sub_progress_bar(all_bar,
                                  label,
                                  total: orphan_fts_targets.count)

        outdated_fts_targets = mapper_class.outdated_fts_targets
        label = "#{redmine_class.name}:Outdated"
        bars[label] =
          create_sub_progress_bar(all_bar,
                                  label,
                                  total: outdated_fts_targets.count)
      end

      all_bar.start
      resolver.each do |redmine_class, mapper_class|
        new_redmine_records =
          mapper_class.not_mapped_redmine_records(project: options.project)
        bar = bars["#{redmine_class.name}:New"]
        bar.start
        bar.iterate(new_redmine_records.pluck(:id).each) do |record_id|
          if options.upsert == :later
            UpsertTargetJob
              .set(priority: UpsertTargetJob.priority + 5)
              .perform_later(mapper_class.name, record_id)
          else
            record = redmine_class.find(record_id)
            mapper = mapper_class.redmine_mapper(record)
            mapper.upsert_fts_target(extract_text: options.extract_text)
          end
        end
        bar.finish

        orphan_fts_targets = mapper_class.orphan_fts_targets
        bar = bars["#{redmine_class.name}:Orphan"]
        bar.start
        bar.iterate(orphan_fts_targets.find_each) do |record|
          record.destroy
        end
        bar.finish

        outdated_fts_targets =
          mapper_class.outdated_fts_targets
            .select(:id,
                    :source_id,
                    :source_type_id)
        bar = bars["#{redmine_class.name}:Outdated"]
        bar.start
        bar.iterate(outdated_fts_targets.find_each) do |record|
          mapper = mapper_class.redmine_mapper(record.source_record)
          mapper.upsert_fts_target(extract_text: options.extract_text)
        end
        bar.finish
      end

      all_bar.finish
    end

    def synchronize_repositories_internal(options)
      if options.project
        projects = [options.project]
      else
        projects = Project.all
      end

      projects.each do |project|
        project.repositories.each do |repository|
          synchronize_repository_internal(repository, options)
        end
      end
    end

    def synchronize_repository_internal(repository, options)
      label = repository.name

      existing_target_ids = {}
      existing_targets =
        Target
          .where(source_type_id: Type.change.id,
                 container_id: repository.id,
                 container_type_id: Type.repository.id)
      existing_bar = create_progress_bar("#{label}:Existing",
                                         total: existing_targets.count)
      existing_bar.start
      each_existing_target = existing_targets.select(:id, :source_id).find_each
      existing_bar.iterate(each_existing_target) do |target|
        existing_target_ids[target.source_id] = target.id
      end
      existing_bar.finish

      mapper_class = FullTextSearch::ChangeMapper
      unless repository.project.archived?
        list_bar = create_progress_bar("#{label}:List",
                                       total: 1)
        list_bar.start
        all_file_entries = repository.scm.all_file_entries
        list_bar.advance
        list_bar.finish

        update_bar = create_progress_bar("#{label}:Update",
                                         total: all_file_entries.size)
        update_bar.iterate(all_file_entries.each) do |entry|
          entry_identifier = entry.lastrev.identifier
          change =
            Change
              .joins(:changeset)
              .find_by(changesets: {
                         repository_id: repository.id,
                         revision: entry_identifier,
                       },
                       path: entry.path)
          next unless change
          existing_target_ids.delete(change.id)
          if options.upsert == :later
            UpsertTargetJob
              .set(priority: UpsertTargetJob.priority + 5)
              .perform_later(mapper_class.name, change.id)
          else
            mapper = mapper_class.redmine_mapper(change)
            mapper.upsert_fts_target(extract_text: options.extract_text)
          end
        end
        update_bar.finish
      end

      return unless process_orphan_change_targets?(repository)
      destroy_bar = create_progress_bar("#{label}:Orphan",
                                        total: existing_target_ids.size)
      destroy_bar.iterate(existing_target_ids.each_value) do |target_id|
        Target.find(target_id).destroy
      end
      destroy_bar.finish
    end

    def process_orphan_change_targets?(repository)
      return true unless repository.supports_revision_graph?
      return true if Target.multiple_column_unique_key_update_is_supported?
      false
    end

    def create_progress_bar(label, *args)
      if @show_progress
        TTY::ProgressBar.new("#{label} #{progress_bar_format}", *args)
      else
        NullProgressBar.new
      end
    end

    def create_multi_progress_bar(label, *args)
      if @show_progress
        TTY::ProgressBar::Multi.new("#{label} #{progress_bar_format}", *args)
      else
        NullProgressBar.new
      end
    end

    def create_sub_progress_bar(bar, label, *args)
      if @show_progress
        bar.register("#{label} #{progress_bar_format}", *args)
      else
        NullProgressBar.new
      end
    end

    def progress_bar_format
      "[:bar] :current/:total(:percent) :eta :rate/s :elapsed"
    end

    class Options < Struct.new(:project,
                               :upsert,
                               :extract_text)
      def project
        raw_project = super
        case raw_project
        when Integer, String
          Project.find(raw_project)
        else
          raw_project
        end
      end

      def upsert
        super || :immediate
      end

      def extract_text
        super || :immediate
      end
    end

    class NullProgressBar
      def iterate(enumerator, &block)
        enumerator.each(&block)
      end

      def start
      end

      def advance
      end

      def finish
      end
    end
  end
end
