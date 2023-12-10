module FullTextSearch
  class DocumentMapper < Mapper
    class << self
      def redmine_mapper_class
        RedmineDocumentMapper
      end

      def fts_mapper_class
        FtsDocumentMapper
      end
    end
  end
  resolver.register(Document, DocumentMapper)

  class RedmineDocumentMapper < RedmineMapper
    def upsert_fts_target(options={})
      fts_target = find_fts_target
      fts_target.source_id = @record.id
      fts_target.source_type_id = Type[@record.class].id
      fts_target.project_id = @record.project_id
      fts_target.title = @record.title
      fts_target.content = @record.description
      fts_target.last_modified_at = @record.created_on
      fts_target.created_at = @record.created_on
      fts_target.save!
    end
  end

  class FtsDocumentMapper < FtsMapper
    def title_prefix
      "#{l(:label_document)}: "
    end

    def url
      {
        controller: "documents",
        action: "show",
        id: @record.source_id,
      }
    end
  end
end
