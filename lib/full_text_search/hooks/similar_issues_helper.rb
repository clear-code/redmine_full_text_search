module FullTextSearch
  module Hooks
    module SimilarIssuesHelper
      def render_similar_issues(issue)
        s = '<table class="list issues odd-even">'
        FullTextSearch::SearcherRecord.similar_issues(id: issue.id).each do |similar_issue|
          css = "list issue issue-#{similar_issue.id} #{similar_issue.css_classes}"
          s << content_tag("tr",
                           content_tag("td", link_to_issue(similar_issue, project: (issue.project_id != similar_issue.project_id)), class: "subject", style: "width: 50%") +
                           content_tag("td", h(similar_issue.status), class: "status") +
                           content_tag("td", link_to_user(similar_issue.assigned_to), class: "assigned_to") +
                           content_tag("td", similar_issue.disabled_core_fields.include?("done_ratio") ? "" : progress_bar(similar_issue.done_ratio), class: "done_ratio"),
                           class: css)
        end
        s << '</table>'
        s.html_safe
      end

      def render_similar_issues2(issue)
        s = '<table class="list issues odd-even">'
        FullTextSearch::SearcherRecord.similar_issues2(id: issue.id).each do |similar_issue|
          css = "issue issue-#{similar_issue.id} #{similar_issue.css_classes}"
          s << content_tag("tr",
                           content_tag("td", link_to_issue(similar_issue, project: (issue.project_id != similar_issue.project_id)), class: "subject", style: "width: 50%") +
                           content_tag("td", h(similar_issue.status), class: "status") +
                           content_tag("td", link_to_user(similar_issue.assigned_to), class: "assigned_to") +
                           content_tag("td", similar_issue.disabled_core_fields.include?("done_ratio") ? "" : progress_bar(similar_issue.done_ratio), class: "done_ratio"),
                           class: css)
        end
        s << '</table>'
        s.html_safe
      end
    end
  end
end
