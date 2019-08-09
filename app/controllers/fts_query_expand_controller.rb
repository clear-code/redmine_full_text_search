class FtsQueryExpandController < ApplicationController
  def index
    @request = FullTextSearch::QueryExpansionRequest.new(request_params)
    @expanded = FtsQueryExpansion.expand_query(@request.query)
    render layout: false if request.xhr?
  end

  private
  def request_params
    params.permit(:query)
  end
end
