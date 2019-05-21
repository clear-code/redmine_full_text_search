module FullTextSearch
  class BatchRunner
    def initialize(show_progress: false)
      @show_progress = show_progress
    end

    def destroy
      destroy_bar = create_progress_bar("Destroy",
                                        total: SearcherRecord.count)
      destroy_bar.iterate(SearcherRecord.find_each) do |record|
        record.destroy
      end
      destroy_bar.finish
    end

    def synchronize(extract_text: nil)
      synchronize_searcher_records(extract_text: extract_text)
    end

    def extract_text(ids: nil)
      attachments = SearcherRecord.where(original_type: "Attachment")
      attachments = attachments.where(id: ids) if ids
      bar = create_progress_bar.new("Extract",
                                    total: attachments.count)
      attachments.find_each do |record|
        record.mapper.redmine_mapper.extract_text
        bar.advance
      end
      bar.finish
    end

    private
    def synchronize_searcher_records(extract_text: nil)
      all_bar = create_multi_progress_bar("All")
      bars = {}

      FullTextSearch.resolver.each do |redmine_class, mapper_class|
        new_redmine_records = mapper_class.not_mapped_redmine_records
        label = "#{redmine_class.name}:New"
        bars[label] =
          create_sub_progress_bar(all_bar,
                                  label,
                                  total: new_redmine_records.count)

        orphan_searcher_records = mapper_class.orphan_searcher_records
        label = "#{redmine_class.name}:Orphan"
        bars[label] =
          create_sub_progress_bar(all_bar,
                                  label,
                                  total: orphan_searcher_records.count)

        outdated_searcher_records = mapper_class.outdated_searcher_records
        label = "#{redmine_class.name}:Outdated"
        bars[label] =
          create_sub_progress_bar(all_bar,
                                  label,
                                  total: outdated_searcher_records.count)
      end

      FullTextSearch.resolver.each do |redmine_class, mapper_class|
        new_redmine_records = mapper_class.not_mapped_redmine_records
        bar = bars["#{redmine_class.name}:New"]
        new_redmine_records.find_each do |record|
          mapper = mapper_class.redmine_mapper(record)
          mapper.upsert_searcher_record(extract_text: extract_text)
          bar.advance
        end
        bar.finish

        orphan_searcher_records = mapper_class.orphan_searcher_records
        bar = bars["#{redmine_class.name}:Orphan"]
        orphan_searcher_records.select(:id).find_each do |record|
          record.destroy
          bar.advance
        end
        bar.finish

        outdated_searcher_records = mapper_class.outdated_searcher_records
        bar = bars["#{redmine_class.name}:Outdated"]
        outdated_searcher_records.select(:id,
                                         :original_id,
                                         :original_type).find_each do |record|
          mapper = mapper_class.redmine_mapper(record.original_record)
          mapper.upsert_searcher_record(extract_text: extract_text)
          bar.advance
        end
        bar.finish
      end

      all_bar.finish
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

      def advance
      end

      def finish
      end
    end
  end
end
