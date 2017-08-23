class LoadCommentsFromChangesets < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        n_records = Changeset.count(:id)
        n_pages = n_records / 1000
        (0..n_pages).each do |offset|
          Changeset.limit(1000).offset(offset * 1000).each do |record|
            short_comments, long_comments = record.comments.split(/(?:\r?\n)+/, 2).map(&:strip)
            FullTextSearch::SearcherRecord
              .where(original_id: record.id, original_type: record.class.name)
              .update_all(short_comments: short_comments, long_comments: long_comments)
          end
        end
      end
      d.down do
        FullTextSearch::SearcherRecord.update_all(short_comments: nil, long_comments: nil)
      end
    end
  end
end
