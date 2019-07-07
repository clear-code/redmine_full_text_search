require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class BatchRunnerSynchronizeTest < ActiveSupport::TestCase
    include PrettyInspectable

    fixtures :attachments
    fixtures :boards
    fixtures :changes
    fixtures :changesets
    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_values
    fixtures :documents
    fixtures :enabled_modules
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :journals
    fixtures :messages
    fixtures :news
    fixtures :projects
    fixtures :projects_trackers
    fixtures :repositories
    fixtures :roles
    fixtures :trackers
    fixtures :users
    fixtures :wiki_pages
    fixtures :wikis

    def setup
      Target.destroy_all
      runner = BatchRunner.new
      runner.synchronize
    end

    def test_new
      issue = Issue.generate!
      target = Target.where(source_type_id: Type.issue.id,
                            source_id: issue.id).first
      target.destroy!
      runner = BatchRunner.new
      assert_difference("Target.count") do
        runner.synchronize
      end
    end

    def test_new_subversion_repository
      project = Project.find(3)
      url = self.class.subversion_repository_url
      repository = Repository::Subversion.create(:project => project,
                                                 :url => url)
      repository.fetch_changesets
      Target.changes.destroy_all
      runner = BatchRunner.new
      assert_difference("Target.count", 7) do
        runner.synchronize
      end
    end

    def test_subversion_repository
      project = Project.find(3)
      url = self.class.subversion_repository_url
      repository = Repository::Subversion.create(:project => project,
                                                 :url => url)
      repository.fetch_changesets
      Target.changes.destroy_all
      runner = BatchRunner.new
      # Including only the latest files at the default branch.
      assert_difference("Target.count", 7) do
        runner.synchronize_repositories(project: project)
      end
    end

    def test_new_git_repository
      unless Target.multiple_column_unique_key_update_is_supported?
        skip("Need Mroonga 9.05 or later")
      end
      project = Project.find(3)
      url = self.class.repository_path("git")
      repository = Repository::Git.create(:project => project,
                                          :url => url)
      repository.fetch_changesets
      Target.changes.destroy_all
      runner = BatchRunner.new
      # Including only the latest files at all branches.
      assert_difference("Target.count", 13) do
        runner.synchronize
      end
    end

    def test_git_repository
      unless Target.multiple_column_unique_key_update_is_supported?
        skip("Need Mroonga 9.05 or later")
      end
      project = Project.find(3)
      url = self.class.repository_path("git")
      repository = Repository::Git.create(:project => project,
                                          :url => url)
      repository.fetch_changesets
      Target.changes.destroy_all
      runner = BatchRunner.new
      assert_difference("Target.count", 9) do
        runner.synchronize_repositories(project: project)
      end
    end

    def test_orphan
      issue = Issue.generate!
      target = Target.where(source_type_id: Type.issue.id,
                            source_id: issue.id).first
      issue.delete
      runner = BatchRunner.new
      assert_difference("Target.count", -1) do
        runner.synchronize
      end
    end

    def test_outdated
      issue = Issue.generate!
      issue.reload
      target = Target.where(source_type_id: Type.issue.id,
                            source_id: issue.id).first
      target.last_modified_at -= 1
      target.save!
      runner = BatchRunner.new
      n_targets = Target.count
      runner.synchronize
      target.reload
      assert_equal([
                     n_targets,
                     issue.updated_on,
                   ],
                   [
                     Target.count,
                     target.last_modified_at,
                   ])
    end

    def test_archived_attachment_issue
      attachment = Attachment.where(container_type: "Issue").first
      attachment.container.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_attachment_project
      attachment = Attachment.where(container_type: "Project").first
      attachment.container.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_attachment_message
      attachment = Attachment.where(container_type: "Message").first
      attachment.container.board.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_attachment_wiki_page
      attachment = Attachment.where(container_type: "WikiPage").first
      attachment.container.wiki.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_change
      change = Change.find(1)
      change.changeset.repository.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_changeset
      changeset = Changeset.find(101)
      changeset.repository.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_custom_value_issue
      searchable_custom_field =
        CustomField
          .where(searchable: true)
          .where(type: "IssueCustomField")
          .first
      custom_value = CustomValue.find_by(custom_field: searchable_custom_field)
      custom_value.customized.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_custom_value_project
      project = Project.find(1)
      custom_field = ProjectCustomField.generate!(searchable: true)
      custom_value = custom_field.custom_values.create!(value: "Hello",
                                                        customized: project)
      project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_document
      document = Document.find(1)
      document.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_issue
      issue = Issue.find(1)
      issue.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_journal
      journal = Journal.find(1)
      journal.journalized.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_message
      message = Message.find(1)
      message.board.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_news
      news = News.find(1)
      news.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_project
      project = Project.find(1)
      project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end

    def test_archived_wiki_page
      wiki_page = WikiPage.find(1)
      wiki_page.wiki.project.archive
      runner = BatchRunner.new
      runner.synchronize
      not_archived_projects = Project.where.not(status: Project::STATUS_ARCHIVED)
      assert_equal([],
                   Target.pluck(:project_id) - not_archived_projects.pluck(:id))
    end
  end
end
