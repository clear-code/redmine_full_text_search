module FullTextSearch
  class BatchRunner
    def initialize(show_progress: false)
      @show_progress = show_progress
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
      destroy_bar = create_progress_bar("Destroy",
                                        total: SearcherRecord.count)
      destroy_bar.iterate(SearcherRecord.find_each) do |record|
        record.destroy
      end
      destroy_bar.finish

      all_bar = create_multi_progress_bar("All")
      bars = {}
      FullTextSearch.resolver.each do |redmine_class, _|
        bars[redmine_class] =
          create_sub_progress_bar(all_bar,
                                  redmine_class.name,
                                  total: redmine_class.count)
      end
      FullTextSearch.resolver.each do |redmine_class, mapper_class|
        bar = bars[redmine_class]
        redmine_class.find_each do |record|
          mapper = mapper_class.redmine_mapper(record)
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
        bar.register("#{label.name} #{progress_bar_format}", *args)
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
