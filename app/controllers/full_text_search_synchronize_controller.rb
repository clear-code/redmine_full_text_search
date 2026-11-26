class FullTextSearchSynchronizeController < ApplicationController
  before_action :require_admin

  def create
    FullTextSearch::SynchronizeJob.perform_later
    flash[:notice] = l(:notice_full_text_search_synchronize_enqueued)
    redirect_to plugin_settings_path("full_text_search")
  end
end
