require File.expand_path("../../../../../test/test_helper", __FILE__)

class SearcherRecordTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :user_preferences, :members, :member_roles, :roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :versions,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :watchers,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries,
           :repositories,
           :boards, :messages,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  include Redmine::I18n

  def setup
    set_language_if_valid "en"
  end

  def teardown
    User.current = nil
  end

  def test_issue_create
    issue = Issue.new(project_id: 1, tracker_id: 1, author_id: 3,
                      status_id: 1, priority: IssuePriority.all.first,
                      subject: "test_create",
                      description: "SearcherRecordTest#test_create_issue", estimated_hours: "1:30")
    assert(issue.save)
    issue.reload
    assert_equal(1.5, issue.estimated_hours)

    record = searcher_record("Issue", issue.id)
    project = Project.find(1)
    assert_equal("test_create", record.subject)
    assert_equal(project.name, record.project_name)
  end

  def test_issue_update
    issue = Issue.new(project_id: 1, tracker_id: 1, author_id: 3, subject: "test_create")
    assert(issue.save)
    assert_equal("test_create", issue.subject)
    record = searcher_record("Issue", issue.id)
    assert_equal("test_create", record.subject)
    issue.subject = "test_issue_update"
    issue.save!
    record.reload
    assert_equal("test_issue_update", record.subject)
  end

  def test_project_create
    project = Project.create!(name: "name", identifier: "name")
    record = searcher_record("Project", project.id)
    assert_equal("name", record.name)
    assert_equal("name", record.project_name)
    project.update!(name: "new-name")
    project.reload
    record.reload
    assert_equal("new-name", record.name)
    assert_equal("new-name", record.project_name)
  end

  def test_news_create
    project = Project.find(1)
    news = project.news.create({ title: "Test news", description: "Lorem ipsum etc", author: User.first })
    record = searcher_record("News", news.id)
    assert_equal("Test news", record.title)
    assert_equal("Lorem ipsum etc", record.description)
    news.update!(description: "Lorem ipsum etc etc")
    record.reload
    assert_equal("Lorem ipsum etc etc", record.description)
  end

  def test_document_create
    doc = Document.create!(project: Project.find(1),
                           title: "New document",
                           category: Enumeration.find_by_name("User documentation"))
    record = searcher_record("Document", doc.id)
    assert_equal("New document", record.title)
    doc.update!(description: "New description")
    record.reload
    assert_equal("New description", record.description)
  end

  def test_changeset_create
    c = Changeset.create!(repository: Project.find(1).repository,
                          committed_on: Time.now,
                          comments: "Add new feature\n\nBecause someone needs it.",
                          revision: "12345")
    record = searcher_record("Changeset", c.id)
    assert_equal("Add new feature\n\nBecause someone needs it.", record.comments)
    assert_equal(c.short_comments, record.short_comments)
    assert_equal(c.long_comments, record.long_comments)
  end

  def test_message_create
    board = Board.find(1)
    user = User.find(1)
    message = Message.create!(board: board, subject: "Test message",
                              content: "Test message content",
                              author: user)
    record = searcher_record("Message", message.id)
    assert_equal("Test message", record.subject)
    assert_equal("Test message content", record.content)
    message.update!(content: "Test message content xxx")
    record.reload
    assert_equal("Test message", record.subject)
    assert_equal("Test message content xxx", record.content)
  end

  def test_journal_create
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, "Test notes")
    journal.save!
    record = searcher_record("Journal", journal.id)
    assert_equal("Test notes", record.notes)
    journal.update!(notes: "Test notes xxx")
    record.reload
    assert_equal("Test notes xxx", record.notes)
  end

  def test_wiki_page_create
    wiki = Wiki.first
    page = WikiPage.create!(wiki: wiki, title: "Page")
    record = searcher_record("WikiPage", page.id)
    assert_equal("Page", record.title)
    page.update!(title: "Page xxx")
    record.reload
    assert_equal("Page_xxx", record.title)
  end

  def test_wiki_content_create
    wiki = Wiki.first
    page = WikiPage.new(wiki: wiki, title: "Page")
    page.content = WikiContent.new(text: "Content text", author: User.find(1), comments: "My comment")
    page.save!
    record = searcher_record("WikiPage", page.id)
    assert_equal("Content text", record.text)
    page.content.text = "Content text xxx"
    page.content.save!
    record.reload
    assert_equal("Content text xxx", record.text)
  end

  def test_custom_value_create
    project = Project.first
    field = CustomField.generate!(searchable: true)
    value = CustomValue.create!(custom_field: field,
                                customized_id: project.id,
                                customized_type: "Project",
                                value: "value")
    record = searcher_record("CustomValue", value.id)
    assert_equal("value", record.value)
    assert_equal(project.id, record.project_id)
    assert_equal(project.name, record.project_name)
    value.update!(value: "value xxx")
    record.reload
    assert_equal("value xxx", record.value)
  end

  def test_issue_custom_value_create
    issue = Issue.first
    field = IssueCustomField.generate!(searchable: true)
    value = CustomValue.create!(custom_field: field,
                                customized_id: issue.id,
                                customized_type: "Issue",
                                value: "value")
    record = searcher_record("CustomValue", value.id)
    assert_equal("value", record.value)
    assert_equal(issue.project.id, record.project_id)
    assert_equal(issue.project.name, record.project_name)
    value.update!(value: "value xxx")
    record.reload
    assert_equal("value xxx", record.value)
  end

  def test_project_attachment
    attachment = Attachment.generate!(container: Project.first,
                                      filename: "project-attachment",
                                      description: "attachment")
    record = searcher_record("Attachment", attachment.id)
    assert_equal("project-attachment", record.filename)
    assert_equal("attachment", record.description)
  end

  def test_message_attachment
    attachment = Attachment.generate!(container: Message.first,
                                      filename: "message-attachment",
                                      description: "attachment")
    record = searcher_record("Attachment", attachment.id)
    assert_equal("message-attachment", record.filename)
    assert_equal("attachment", record.description)
  end

  def test_wiki_page_attachment
    attachment = Attachment.generate!(container: WikiPage.first,
                                      filename: "wiki-attachment",
                                      description: "attachment")
    record = searcher_record("Attachment", attachment.id)
    assert_equal("wiki-attachment", record.filename)
    assert_equal("attachment", record.description)
  end

  def test_issue_attachment
    attachment = Attachment.generate!(container: Issue.first,
                                      filename: "issue-attachment",
                                      description: "attachment")
    record = searcher_record("Attachment", attachment.id)
    assert_equal("issue-attachment", record.filename)
    assert_equal("attachment", record.description)
  end

  private

  def searcher_record(original_type, original_id)
    FullTextSearch::SearcherRecord.where(
      original_type: original_type,
      original_id: original_id
    ).first
  end
end
