module FullTextSearch
  module Model
    def self.included(base)
      base.class_eval do
        after_save Callbacks
      end
    end

    class Callbacks
      # 全文検索用テーブルにデータをコピーする。検索と結果表示に使うカラムだけ。
      def self.after_save(record)
        searcher_record =
          FullTextSearch::SearcherRecord.find_or_create_by!(original_id: record.id,
                                                            original_type: record.class.name)
        case record
        when Project
          searcher_record.update_attributes!(name: record.name,
                                             description: record.description,
                                             identifier: record.identifier,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when News
          searcher_record.update_attributes!(title: record.title,
                                             summary: record.summary,
                                             description: record.description,
                                             created_on: record.created_on)
        when Issue
          searcher_record.update_attributes!(subject: record.subject,
                                             description: record.subject,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when Document
          searcher_record.update_attributes!(title: record.title,
                                             description: record.description,
                                             created_on: record.created_on)
        when Changeset
          searcher_record.update_attributes!(comments: record.comments,
                                             created_on: record.committed_on)
        when Message
          searcher_record.update_attributes!(subject: record.subject,
                                             content: record.content,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when Journal
          searcher_record.update_attributes!(notes: record.notes,
                                             created_on: record.created_on)
        when WikiPage
          searcher_record.update_attributes!(title: record.title,
                                             created_on: record.created_on)
        when WikiContent
          searcher_record.update_attributes!(text: record.text,
                                             updated_on: record.updated_on)
        when CustomValue
          searcher_record.update_attributes!(value: record.value)
        when Attachment
          searcher_record.update_attributes!(filename: record.filename,
                                             description: record.description,
                                             created_on: record.created_on)
        else
          # do nothing
        end
      end
    end
  end
end
