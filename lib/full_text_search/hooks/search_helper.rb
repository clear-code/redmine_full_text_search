module FullTextSearch
  module Hooks
    module SearchHelper
      include FullTextSearch::Hooks::SettingsHelper

      unless ActionView::Helpers::FormHelper.method_defined?(:form_with)
        def form_with(model: nil, **options, &block)
          form_for(model, **options, &block)
        end
      end

      unless ActionView::Helpers::TagHelper.const_defined?(:TagBuilder)
        class TagBuilder
          def initialize(view_context)
            @view_context = view_context
          end

          def method_missing(name, *args, &block)
            @view_context.tag(name, *args, &block)
          end
        end

        def tag(*args, &block)
          if args.empty?
            TagBuilder.new(self)
          else
            super
          end
        end
      end

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
