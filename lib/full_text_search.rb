module FullTextSearch
  class << self
    def target_classes
      [
        Attachment,
        Changeset,
        CustomValue,
        Document,
        Issue,
        Journal,
        Message,
        News,
        Project,
        WikiContent,
        WikiPage,
      ]
    end
  end
end
