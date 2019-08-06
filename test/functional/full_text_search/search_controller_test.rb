require File.expand_path("../../../test_helper", __FILE__)

module FullTextSearch
  class SearchControllerTest < Redmine::ControllerTest
    include PrettyInspectable

    include GroongaCommandExecutable

    tests SearchController

    fixtures :attachments
    fixtures :boards
    fixtures :changesets
    fixtures :custom_fields
    fixtures :custom_fields_projects
    fixtures :custom_fields_trackers
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
    fixtures :trackers
    fixtures :users
    fixtures :wiki_contents
    fixtures :wiki_pages
    fixtures :wikis

    def setup
      Target.destroy_all
      batch_runner = BatchRunner.new(show_progress: false)
      batch_runner.synchronize
      execute_groonga_command("plugin_register functions/vector")
      @user = User.admin.first
      @request.session[:user_id] = @user.id
      @search_id = "2.9"
    end

    def adjust_slice_score(score)
      if Target.slice_drilldown_is_supported?
        score + 1
      else
        score
      end
    end

    def get(action, params: {}, api: false)
      if api
        with_settings(rest_api_enabled: 1) do
          super(action, params: params.merge(key: @user.api_key,
                                             format: "json"))
        end
      else
        super(action, params: params.merge(search_id: @search_id))
      end
    end

    def item_url(item,
                 search_id: nil,
                 search_n: nil,
                 only_path: false)
      case item
      when Attachment
        attachment = item
        named_attachment_url(id: attachment.id,
                             filename: attachment.filename,
                             search_id: search_id,
                             search_n: search_n,
                             only_path: only_path)
      when Change
        change = item
        changeset = change.changeset
        repository = changeset.repository
        path = repository.relative_path(change.path).gsub(/\A\//, "")
        url_parameters = {
          controller: "repositories",
          action: "entry",
          id: repository.project_id,
          repository_id: repository.identifier_param,
          rev: changeset.identifier,
          path: path,
          search_id: search_id,
          search_n: search_n,
          only_path: only_path,
        }
        @controller.url_for(url_parameters)
      when Changeset
        changeset = item
        url_parameters = {
          controller: "repositories",
          action: "revision",
          id: changeset.repository.project_id,
          repository_id: changeset.repository.identifier_param,
          rev: changeset.identifier,
          search_id: search_id,
          search_n: search_n,
          only_path: only_path,
        }
        @controller.url_for(url_parameters)
      when Issue
        issue = item
        issue_url(issue,
                  search_id: search_id,
                  search_n: search_n,
                  only_path: only_path)
      when Journal
        journal = item
        issue = journal.journalized
        issue_url(issue,
                  search_id: search_id,
                  search_n: search_n,
                  anchor: "change-#{journal.id}",
                  only_path: only_path)
      when Message
        message = item
        board_message_url(message.board,
                          message,
                          search_id: search_id,
                          search_n: search_n,
                          only_path: only_path)
      when WikiPage
        wiki_page = item
        project_wiki_page_url(wiki_page.project.id,
                              wiki_page.title,
                              search_id: search_id,
                              search_n: search_n,
                              only_path: only_path)
      else
        raise "Unsupported item: #{item.inspect}"
      end
    end

    def item_title(item)
      case item
      when Attachment
        attachment = item
        attachment.filename
      when Change
        change = item
        changeset = change.changeset
        repository = changeset.repository
        title = ""
        title << "#{repository.identifier}:" unless repository.identifier.blank?
        title << "#{change.path}@#{changeset.revision}"
        title
      when Changeset
        changeset = item
        "Revision #{changeset.revision}: #{changeset.comments}"
      when Issue
        issue = item
        "#{issue.tracker.name} \##{issue.id} (#{issue.status.name}): " +
          "#{issue.subject}"
      when Journal
        journal = item
        issue = journal.journalized
        "#{issue.tracker.name} \##{issue.id}\#change-#{journal.id} " +
          "(#{issue.status.name}): " +
          "#{issue.subject}"
      when Message
        message = item
        "#{message.board.name}: #{message.subject}"
      when WikiPage
        wiki_page = item
        "Wiki: #{wiki_page.title}"
      else
        raise "Unsupported item: #{item.inspect}"
      end
    end

    def format_items(items)
      items.collect.with_index do |item, i|
        [
          item_title(item),
          item_url(item,
                   search_id: @search_id,
                   search_n: i,
                   only_path: true),
        ]
      end
    end

    def format_api_results(items, total_count: nil)
      results = items.collect do |item, detail|
        datetime = nil
        if item.respond_to?(:customized)
          customized = item.customized
          if customized.respond_to?(:updated_on)
            datetime ||= customized.updated_on
          end
          if customized.respond_to?(:created_on)
            datetime ||= customized.created_on
          end
        end
        datetime ||= item.committed_on if item.respond_to?(:committed_on)
        if item.respond_to?(:changeset)
          datetime ||= item.changeset.committed_on
        end
        datetime ||= item.updated_on if item.respond_to?(:updated_on)
        datetime ||= item.created_on if item.respond_to?(:created_on)
        {
          "id" => item.id,
          "title" => detail[:title] || item_title(item),
          "type" => detail[:type] || item.class.name.underscore.dasherize,
          "url" => item_url(item),
          "description" => detail[:description],
          "datetime" => datetime&.iso8601,
          "rank" => detail[:rank],
        }
      end
      {
        "results" => results,
        "total_count" => total_count || items.size,
        "offset" => 0,
        "limit" => 25,
      }
    end

    class UITest < self
      def test_search_order_in_options
        get :index
        assert_select("#options-content") do
          assert_select(".full-text-search-order")
        end
      end

      def test_search_order_links
        project = Project.first
        get :index, params: {"id" => project.identifier}
        assert_select(".search-order") do
          items = css_select(@selected, "li").collect do |li|
            href = (css_select(li, "a").first || {})["href"]
            if href
              uri = URI.parse(href)
              search_path = uri.path
              search_options = Rack::Utils.parse_query(uri.query)
            else
              search_path = nil
              search_options = nil
            end
            [
              li.text.strip,
              search_path,
              search_options,
            ]
          end
          common_search_options = {
            "all_words" => "1",
            "attachments" => "1",
            "changes" => "1",
            "changesets" => "1",
            "documents" => "1",
            "files" => "1",
            "issues" => "1",
            "limit" => "10",
            "messages" => "1",
            "news" => "1",
            "offset" => "0",
            "open_issues" => "0",
            "options" => "0",
            "q" => "",
            "titles_only" => "0",
            "wiki_pages" => "1",
            "search_id" => @search_id,
          }
          expected_search_path = "/projects/#{project.identifier}/search"
          assert_equal([
                         ["score", nil, nil],
                         [
                           "updated at",
                           expected_search_path,
                           common_search_options.merge("order_target" => "date",
                                                       "order_type" => "desc"),
                         ],
                         [
                           "asc",
                           expected_search_path,
                           common_search_options.merge("order_target" => "score",
                                                       "order_type" => "asc"),
                         ],
                         ["desc", nil, nil],
                       ],
                       items)
        end
      end

      def test_drilldowns
        project = Project.first
        get :index, params: {"id" => project.identifier}
        assert_select("#search-source-types") do
          items = css_select(@selected, "li").collect do |li|
            href = (css_select(li, "a").first || {})["href"]
            if href
              uri = URI.parse(href)
              search_path = uri.path
              search_options = Rack::Utils.parse_query(uri.query)
            else
              search_path = nil
              search_options = nil
            end
            [
              li.text.strip,
              search_path,
              search_options,
            ]
          end
          common_search_options = {
            "all_words" => "1",
            "attachments" => "1",
            "limit" => "10",
            "offset" => "0",
            "open_issues" => "0",
            "options" => "0",
            "order_target" => "score",
            "order_type" => "desc",
            "q" => "",
            "titles_only" => "0",
            "search_id" => @search_id,
          }
          expected_search_path = "/projects/#{project.identifier}/search"
          assert_equal([
                         [
                           "All (50)",
                           expected_search_path,
                           common_search_options.merge("changes" => "1",
                                                       "changesets" => "1",
                                                       "documents" => "1",
                                                       "files" => "1",
                                                       "issues" => "1",
                                                       "messages" => "1",
                                                       "news" => "1",
                                                       "wiki_pages" => "1"),
                         ],
                         [
                           "Issues (20)",
                           expected_search_path,
                           common_search_options.merge("issues" => "1"),
                         ],
                         [
                           "News (2)",
                           expected_search_path,
                           common_search_options.merge("news" => "1"),
                         ],
                         [
                           "Documents (2)",
                           expected_search_path,
                           common_search_options.merge("documents" => "1"),
                         ],
                         [
                           "Changesets (10)",
                           expected_search_path,
                           common_search_options.merge("changesets" => "1"),
                         ],
                         [
                           "Wiki pages (9)",
                           expected_search_path,
                           common_search_options.merge("wiki_pages" => "1"),
                         ],
                         [
                           "Messages (7)",
                           expected_search_path,
                           common_search_options.merge("messages" => "1"),
                         ],
                         [
                           "Changes (0)",
                           expected_search_path,
                           common_search_options.merge("changes" => "1"),
                         ],
                         [
                           "Files (0)",
                           expected_search_path,
                           common_search_options.merge("files" => "1"),
                         ],
                       ],
                       items)
        end
      end
    end

    class AttachmentTest < self
      def setup
        super
        file = uploaded_test_file("testfile.txt", "text/plain")
        @attachment = Attachment.generate!(file: file)
      end

      def search(query, api: false)
        get :index, params: {"q" => query, "issues" => "1"}, api: api
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

      def test_api
        search("upload", api: true)
        attachments = [
          [
            @attachment,
            {
              title: @attachment.filename,
              description: <<-DESCRIPTION,
this is a text file for <span class="keyword">upload</span> tests\r
with multiple lines\r
              DESCRIPTION
              rank: adjust_slice_score(2),
            }
          ],
        ]
        assert_equal(format_api_results(attachments),
                     JSON.parse(response.body))
      end
    end

    class ChangesetTest < self
      def search(query, api: false)
        get :index, params: {"q" => query, "changesets" => "1"}, api: api
      end

      def test_search
        search("helloworld")
        items = [
          Changeset.find(105),
        ]
        assert_select("#search-results") do
          assert_equal(format_items(items),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end

      def test_api
        search("helloworld", api: true)
        items = [
          [
            Changeset.find(105),
            {
              title: <<-TITLE.chomp,
Revision 6: Moved <span class="keyword">helloworld</span>.rb from / to /folder.
              TITLE
              description: "",
              rank: adjust_slice_score(101),
            }
          ],
        ]
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end

    class ChangeRootURLTest < self
      def setup
        super
        @project = Project.find(3)
        url = self.class.subversion_repository_url
        @repository = Repository::Subversion.create(:project => @project,
                                                    :url => url)
        @repository.fetch_changesets
      end

      def search(query, api: false)
        get :index,
            params: {
              "id" => @project.identifier,
              "q" => query,
              "changes" => "1",
            },
            api: api
      end

      def test_search
        search("redmine")
        revision10 = @repository.changesets.find_by(revision: "10").filechanges
        revision11 = @repository.changesets.find_by(revision: "11").filechanges
        items = [
          revision11.find_by(path: "/subversion_test/[folder_with_brackets]/README.txt"),
          revision10.find_by(path: "/subversion_test/folder/subfolder/journals_controller.rb"),
        ]
        assert_select("#search-results") do
          assert_equal(format_items(items),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end

      def test_api
        search("redmine", api: true)
        revision10 = @repository.changesets.find_by(revision: "10").filechanges
        revision11 = @repository.changesets.find_by(revision: "11").filechanges
        items = [
          [
            revision11.find_by(path: "/subversion_test/[folder_with_brackets]/README.txt"),
            {
              type: "file",
              title: <<-TITLE.chomp,
/subversion_test/[folder_with_brackets]/README.txt@11
              TITLE
              description: <<-DESCRIPTION,
This file should be accessible for <span class="keyword">Redmine</span>, although its folder contains square
brackets.
              DESCRIPTION
              rank: adjust_slice_score(2),
            }
          ],
          [
            revision10.find_by(path: "/subversion_test/folder/subfolder/journals_controller.rb"),
            {
              type: "file",
              title: <<-TITLE.chomp,
/subversion_test/folder/subfolder/journals_controller.rb@10
              TITLE
              description: <<-DESCRIPTION.chomp,
# <span class="keyword">redMine</span> - project management software\r
# Copyright (C) 2006-2008  Jean-Philippe Lang\r
#\r
# This program is free software; you can redistribute it and/or\r
# modify it under the terms of the GNU Gener
              DESCRIPTION
              rank: adjust_slice_score(2),
            },
          ],
        ]
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end

    class ChangeSubURLTest < self
      def setup
        super
        @project = Project.find(3)
        url = "#{self.class.subversion_repository_url}/subversion_test"
        @repository = Repository::Subversion.create(:project => @project,
                                                    :url => url)
        @repository.fetch_changesets
      end

      def search(query, api: false)
        get :index,
            params: {
              "id" => @project.identifier,
              "q" => query,
              "changes" => "1",
            },
            api: api
      end

      def test_search
        search("redmine")
        revision10 = @repository.changesets.find_by(revision: "10").filechanges
        revision11 = @repository.changesets.find_by(revision: "11").filechanges
        items = [
          revision11.find_by(path: "/subversion_test/[folder_with_brackets]/README.txt"),
          revision10.find_by(path: "/subversion_test/folder/subfolder/journals_controller.rb"),
        ]
        assert_select("#search-results") do
          assert_equal(format_items(items),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end

      def test_api
        search("redmine", api: true)
        revision10 = @repository.changesets.find_by(revision: "10").filechanges
        revision11 = @repository.changesets.find_by(revision: "11").filechanges
        items = [
          [
            revision11.find_by(path: "/subversion_test/[folder_with_brackets]/README.txt"),
            {
              type: "file",
              title: <<-TITLE.chomp,
/subversion_test/[folder_with_brackets]/README.txt@11
              TITLE
              description: <<-DESCRIPTION,
This file should be accessible for <span class="keyword">Redmine</span>, although its folder contains square
brackets.
              DESCRIPTION
              rank: adjust_slice_score(2),
            }
          ],
          [
            revision10.find_by(path: "/subversion_test/folder/subfolder/journals_controller.rb"),
            {
              type: "file",
              title: <<-TITLE.chomp,
/subversion_test/folder/subfolder/journals_controller.rb@10
              TITLE
              description: <<-DESCRIPTION.chomp,
# <span class="keyword">redMine</span> - project management software\r
# Copyright (C) 2006-2008  Jean-Philippe Lang\r
#\r
# This program is free software; you can redistribute it and/or\r
# modify it under the terms of the GNU Gener
              DESCRIPTION
              rank: adjust_slice_score(2),
            },
          ],
        ]
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end

    class CustomFieldTest < self
      def search(query, params: {}, api: false)
        get :index,
            params: {"q" => query, "issues" => "1"}.merge(params),
            api: api
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
        search("searchable", params: {id: project1.id})
        assert_select("#search-results") do
          assert_equal(format_items([issue1]),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end

      def test_api
        searchable_custom_field = CustomField.where(searchable: true).first
        tracker = searchable_custom_field.trackers.first
        project1, project2, = tracker.projects
        custom_field_values = {
          searchable_custom_field.id => "Searchable",
        }
        issue1 = generate_issue!(project1, custom_field_values)
        issue2 = generate_issue!(project2, custom_field_values)
        search("searchable",
               params: {id: project1.id},
               api: true)
        items = [
          [
            issue1,
            {
              description: %Q[<span class="keyword">Searchable</span>],
              rank: adjust_slice_score(2),
            }
          ],
        ]
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end

    class IssueTest < self
      def search(query, api: false)
        get :index,
            params: {"q" => query, "issues" => "1"},
            api: api
      end

      def test_search
        search("print OR (private (subproject OR version))")
        items = [
          Issue.find(6),
          Issue.find(1),
          Journal.find(4),
        ]
        assert_select("#search-results") do
          assert_equal(format_items(items),
                       css_select("dt a").collect {|a| [a.text, a["href"]]})
        end
      end

      def test_api
        search("print OR (private (subproject OR version))",
               api: true)
        items = [
          [
            Issue.find(6),
            {
              title: <<-TITLE.chomp,
Bug #6 (New): Issue of a <span class="keyword">private</span> <span class="keyword">subproject</span>
              TITLE
              description: <<-DESCRIPTION.chomp,
This is an issue of a <span class="keyword">private</span> <span class="keyword">subproject</span> of cookbook
              DESCRIPTION
              rank: adjust_slice_score(203),
            },
          ],
          [
            Issue.find(1),
            {
              title: <<-TITLE.chomp,
Bug #1 (New): Cannot <span class="keyword">print</span> recipes
              TITLE
              description: <<-DESCRIPTION.chomp,
Unable to <span class="keyword">print</span> recipes
              DESCRIPTION
              rank: adjust_slice_score(102),
            },
          ],
          [
            Journal.find(4),
            {
              type: "issue-note",
              description: <<-DESCRIPTION.chomp,
A comment with a <span class="keyword">private</span> <span class="keyword">version</span>.
              DESCRIPTION
              rank: adjust_slice_score(3),
            },
          ],
        ]
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end

    class MessageTest < self
      def search(query, api: false)
        get :index,
            params: {"q" => query, "forums" => "1"},
            api: api
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

      def test_api
        items = [
          [
            Message.find(1),
            {
              title: <<-TITLE.chomp,
Help: <span class="keyword">First</span> <span class="keyword">post</span>
              TITLE
              description: <<-DESCRIPTION.chomp,
This is the very <span class="keyword">first</span> <span class="keyword">post</span>
in the forum
              DESCRIPTION
              rank: adjust_slice_score(203),
            },
          ],
          [
            Message.find(3),
            {
              type: "reply",
              title: <<-TITLE.chomp,
Help: RE: <span class="keyword">First</span> <span class="keyword">post</span>
              TITLE
              description: "",
              rank: adjust_slice_score(201),
            },
          ],
          [
            Message.find(2),
            {
              type: "reply",
              title: <<-TITLE.chomp,
Help: <span class="keyword">First</span> reply
              TITLE
              description: <<-DESCRIPTION.chomp,
Reply to the <span class="keyword">first</span> <span class="keyword">post</span>
              DESCRIPTION
              rank: adjust_slice_score(103),
            },
          ],
        ]
        search("first post", api: true)
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end

    class WikiPageTest < self
      def search(query, api: false)
        get :index,
            params: {"q" => "cookbook gzipped", "wiki_pages" => "1"},
            api: api
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

      def test_api
        items = [
          [
            WikiPage.find(1),
            {
              title: <<-TITLE.chomp,
Wiki: <span class="keyword">CookBook</span>_documentation
              TITLE
              description: <<-DESCRIPTION.chomp,
h1. <span class="keyword">CookBook</span> documentation

{{child_pages}}

Some updated [[documentation]] here with <span class="keyword">gzipped</span> history
              DESCRIPTION
              rank: adjust_slice_score(103),
            },
          ],
        ]
        search("first post", api: true)
        assert_equal(format_api_results(items),
                     JSON.parse(response.body))
      end
    end
  end
end
