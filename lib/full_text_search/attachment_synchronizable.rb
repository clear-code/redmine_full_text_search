module FullTextSearch
  module AttachmentSynchronizable
    extend ActiveSupport::Concern

    included do
      after_commit :queue_sync_on_commit
      after_destroy :queue_sync_on_destroy
    end

    private

    def queue_sync(action, options = {})
      FullTextSearch::UpdateIssueContentJob.perform_later(
        self.class.name,
        self.id,
        action,
        options
      )
    end

    def queue_sync_on_commit
      queue_sync("commit")
    end

    def queue_sync_on_destroy
      return if self.container_type != Issue.name
      queue_sync("destroy", issue_id: self.container_id)
    end
  end
end
