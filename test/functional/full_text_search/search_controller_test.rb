require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearchControllerTest < Redmine::ControllerTest
    include GroongaCommandExecutable

    make_my_diffs_pretty!

    tests SearchController

    fixtures :attachments
    fixtures :boards
    fixtures :changesets
    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_fields_trackers
    fixtures :custom_values
    fixtures :enabled_modules
    fixtures :enumerations
    fixtures :issue_statuses
    fixtures :issues
    fixtures :journals
    fixtures :messages
    fixtures :projects
    fixtures :projects_trackers
    fixtures :repositories
    fixtures :trackers
    fixtures :users
    fixtures :wiki_contents
    fixtures :wiki_pages
    fixtures :wikis

    def setup
      batch_runner = BatchRunner.new(show_progress: false)
      batch_runner.destroy
      batch_runner.synchronize
      execute_groonga_command("plugin_register functions/vector")
      @request.session[:user_id] = User.admin.first.id
    end

    def format_items(items)
      items.collect do |item|
        case item
        when Attachment
          attachment = item
          [
            attachment.filename,
            named_attachment_path(id: attachment.id,
                                  filename: attachment.filename),
          ]
        when Changeset
          changeset = item
          label = "Revision #{changeset.revision}: #{changeset.comments}"
          path_parameters = {
            controller: "repositories",
            action: "revision",
            id: changeset.repository.project_id,
            repository_id: changeset.repository.identifier_param,
            rev: changeset.identifier,
          }
          [label, @routes.path_for(path_parameters)]
        when Issue
          issue = item
          label =
            "#{issue.tracker.name} \##{issue.id} (#{issue.status.name}): " +
            "#{issue.subject}"
          [label, issue_path(issue)]
        when Journal
          journal = item
          issue = journal.journalized
          label =
            "#{issue.tracker.name} \##{issue.id} (#{issue.status.name}): " +
            "#{issue.subject}"
          [label, issue_path(issue, anchor: "change-#{journal.id}")]
        when Message
          message = item
          [
            "#{message.board.name}: #{message.subject}",
            board_message_path(message.board, message),
          ]
        when WikiPage
          wiki_page = item
          [
            "Wiki: #{wiki_page.title}",
            project_wiki_page_path(wiki_page.project.id, wiki_page.title),
          ]
        else
          raise "Unsupported item: #{item.inspect}"
        end
      end
    end

    class OptionsTest < self
      def test_index
        get :index
        assert_select("#options-content") do
          assert_select(".full-text-search-order")
        end
      end
    end

    class AttachmentTest < self
      def setup
        super
        file = uploaded_test_file("testfile.txt", "text/plain")
        @attachment = Attachment.generate!(file: file)
      end

      def search(query)
        get :index, params: {"q" => query, "issues" => "1"}
      end

      def test_search
        search("upload")
        attachments = [
          @attachment,
        ]
        assert_select("#search-results") do
          assert_equal(format_items(attachments),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end
    end

    class ChangesetTest < self
      def search(query)
        get :index, params: {"q" => query, "changesets" => "1"}
      end

      def test_search
        search("helloworld")
        attachments = [
          Changeset.find(105),
        ]
        assert_select("#search-results") do
          assert_equal(format_items(attachments),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end
    end

    class CustomFieldTest < self
      def search(query, params={})
        get :index, params: {"q" => query, "issues" => "1"}.merge(params)
      end

      def generate_issue!(project, custom_field_values)
        issue = Issue.generate!(project: project)
        issue.custom_field_values = custom_field_values
        issue.save!
        issue
      end

      def test_scoped
        searchable_custom_field = CustomField.where(searchable: true).first
        tracker = searchable_custom_field.trackers.first
        project1, project2, = tracker.projects
        custom_field_values = {
          searchable_custom_field.id => "Searchable",
        }
        issue1 = generate_issue!(project1, custom_field_values)
        issue2 = generate_issue!(project2, custom_field_values)
        search("searchable", id: project1.id)
        assert_select("#search-results") do
          assert_equal(format_items([issue1]),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end
    end

    class IssueTest < self
      def search(query)
        get :index, params: {"q" => query, "issues" => "1"}
      end

      def test_search
        search("print OR (private (subproject OR version))")
        issues = [
          Issue.find(6),
          Issue.find(1),
          Journal.find(4),
        ]
        assert_select("#search-results") do
          assert_equal(format_items(issues),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end
    end

    class MessageTest < self
      def search(query)
        get :index, params: {"q" => query, "forums" => "1"}
      end

      def test_search
        messages = [
          Message.find(1),
          Message.find(3),
          Message.find(2),
        ]
        search("first post")
        assert_select("#search-results") do
          assert_equal(format_items(messages),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end
    end

    class WikiPageTest < self
      def search(query)
        get :index, params: {"q" => "cookbook gzipped", "wiki_pages" => "1"}
      end

      def test_search
        messages = [
          WikiPage.find(1),
        ]
        search("first post")
        assert_select("#search-results") do
          assert_equal(format_items(messages),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end
    end
  end
end
