module FullTextSearch
  class DocumentMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineDocumentMapper
      end

      def searcher_mapper_class
        SearcherDocumentMapper
      end
    end
  end
  resolver.register(Document, DocumentMapper)

  class RedmineDocumentMapper < RedmineMapper
    def upsert_searcher_record(options={})
      searcher_record = find_searcher_record
      searcher_record.original_id = @record.id
      searcher_record.original_type = @record.class.name
      searcher_record.project_id = @record.project_id
      searcher_record.project_name = @record.project.name
      searcher_record.title = @record.title
      searcher_record.description = @record.description
      searcher_record.original_created_on = @record.created_on
      searcher_record.save!
    end
  end

  class SearcherDocumentMapper < SearcherMapper
    def title_prefix
      "#{l(:label_document)}: "
    end

    def url
      {
        controller: "documents",
        action: "show",
        id: @record.original_id,
      }
    end
  end
end
