module FullTextSearch
  module Hooks
    module SearchHelper
      include FullTextSearch::Hooks::SettingsHelper
      # Overwrite SearchHelper#render_results_by_type to add order_target and order_type
      def render_results_by_type(results_by_type)
        links = []
        # Sorts types by results count
        results_by_type.keys.sort {|a, b| results_by_type[b] <=> results_by_type[a]}.each do |t|
          c = results_by_type[t]
          next if c == 0
          text = "#{type_label(t)} (#{c})"
          links << link_to(h(text),
                           :q => params[:q],
                           :titles_only => params[:titles_only],
                           :all_words => params[:all_words],
                           :scope => params[:scope],
                           :order_target => params[:order_target],
                           :order_type => params[:order_type],
                           t => 1)
        end
        ('<ul>'.html_safe +
         links.map {|link| content_tag('li', link)}.join(' ').html_safe + 
         '</ul>'.html_safe) unless links.empty?
      end
    end
  end
end
