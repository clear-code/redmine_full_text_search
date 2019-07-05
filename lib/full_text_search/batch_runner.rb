module FullTextSearch
  class BatchRunner
    def initialize(show_progress: false)
      @show_progress = show_progress
    end

    def synchronize(project: nil,
                    upsert: nil,
                    extract_text: nil)
      project = Project.find(project) if project
      upsert ||= :immediate
      extract_text ||= :immediate
      synchronize_fts_targets(project,
                              upsert,
                              extract_text)
      synchronize_repositories(project,
                               upsert,
                               extract_text)
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
    def synchronize_fts_targets(project, upsert, extract_text)
      all_bar = create_multi_progress_bar("FullTextSearch::Target:All")
      bars = {}

      resolver = FullTextSearch.resolver
      resolver.each do |redmine_class, mapper_class|
        new_redmine_records = mapper_class.not_mapped_redmine_records
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
        new_redmine_records = mapper_class.not_mapped_redmine_records
        bar = bars["#{redmine_class.name}:New"]
        bar.start
        new_redmine_records.find_each do |record|
          if mapper_class.need_text_extraction? and upsert == :later
            UpsertTargetJob.perform_later(mapper_class.name, record.id)
          else
            mapper = mapper_class.redmine_mapper(record)
            mapper.upsert_fts_target(extract_text: extract_text)
          end
          bar.advance
        end
        bar.finish

        orphan_fts_targets = mapper_class.orphan_fts_targets
        bar = bars["#{redmine_class.name}:Orphan"]
        bar.start
        orphan_fts_targets.select(:id).find_each do |record|
          record.destroy
          bar.advance
        end
        bar.finish

        outdated_fts_targets = mapper_class.outdated_fts_targets
        bar = bars["#{redmine_class.name}:Outdated"]
        bar.start
        outdated_fts_targets.select(:id,
                                    :source_id,
                                    :source_type_id).find_each do |record|
          mapper = mapper_class.redmine_mapper(record.source_record)
          mapper.upsert_fts_target(extract_text: extract_text)
          bar.advance
        end
        bar.finish
      end

      all_bar.finish
    end

    def synchronize_repositories(project, upsert, extract_text)
      if project
        projects = [project]
      else
        projects = Project.all
      end

      all_bar = create_multi_progress_bar("FullTextSearch::RepositoryFile:All")
      projects.each do |_project|
        _project.repositories.each do |repository|
          synchronize_repository(repository, upsert, extract_text, all_bar)
        end
      end
      all_bar.finish
    end

    def synchronize_repository(repository, upsert, extract_text, all_bar)
      current_targets = {}
      Target
        .where(source_type_id: Type.change.id,
               container_id: repository.id,
               container_type_id: Type.repository.id)
        .pluck(:id, :source_id)
        .each do |id, source_id|
        current_targets[source_id] = id
      end
      mapper_class = FullTextSearch::ChangeMapper
      unless repository.project.archived?
        all_file_entries = repository.scm.all_file_entries
        update_bar = create_sub_progress_bar(all_bar,
                                             "#{repository.identifier}:Update",
                                             total: all_file_entries.size)
        update_bar.iterate(all_file_entries.each) do |entry|
          entry_identifier = entry.lastrev.identifier
          change =
            Change
              .joins(changeset: :repository)
              .where(repositories: {id: repository.id},
                     changesets: {revision: entry_identifier},
                     path: entry.path)
              .first
          next unless change
          current_targets.delete(change.id)
          if upsert == :later
            UpsertTargetJob.perform_later(mapper_class.name, change.id)
          else
            mapper = mapper_class.redmine_mapper(change)
            mapper.upsert_fts_target(extract_text: extract_text)
          end
        end
        update_bar.finish
      end

      return unless process_orphan_change_targets?(repository)
      destroy_bar = create_sub_progress_bar(all_bar,
                                            "#{repository.identifier}:Orphan",
                                            total: current_targets.size)
      destroy_bar.iterate(current_targets.each_value) do |target_id|
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
