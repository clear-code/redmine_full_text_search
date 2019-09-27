module FullTextSearch
  class MarkupParser
    include ERB::Util
    include ActionView::Helpers
    include Rails.application.routes.url_helpers
    include ApplicationHelper

    def initialize(project)
      @project = project
      assign_controller(WelcomeController.new)
      controller.request = ActionDispatch::Request.new({})
    end

    def parse(object, attribute, options={})
      html = with_user(User.admin.first) do
        textilizable(object, attribute, options)
      end
      document = Document.new
      parser = Nokogiri::HTML::SAX::Parser.new(document)
      parser.parse(html)
      [document.text.strip, document.tag_ids]
    end

    private
    def with_user(user)
      current_user = User.current
      begin
        User.current = user
        yield
      ensure
        User.current = current_user
      end
    end

    class Document < Nokogiri::XML::SAX::Document
      attr_reader :text
      attr_reader :tag_ids
      def initialize
        @text = ""
        @tag_ids = []

        @tag_stack = []
        @attributes_stack =[]
        @in_body = false
      end

      def start_element(name, attributes=[])
        @tag_stack.push(name)
        @attributes_stack.push(attributes)
        unless @in_body
          @in_body = (@tag_stack == ["html", "body"])
          return
        end
      end

      def end_element(name)
        @attributes_stack.pop
        @tag_stack.pop
        return unless @in_body

        if name == "body" and @tag_stack == ["html"]
          @in_body = false
          return
        end
      end

      def characters(text)
        @text << text if in_target_text?
      end

      private
      def in_target_text?
        return false unless @in_body

        @attributes_stack.last.each do |name, value|
          case name
          when "class"
            return false if value.split(/\s+/).include?("wiki-anchor")
          end
        end
        true
      end
    end
  end
end
