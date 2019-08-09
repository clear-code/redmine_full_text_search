class FtsQueryExpansionsController < ApplicationController
  layout "admin"
  self.main_menu = false
  before_action :require_admin

  helper :sort
  include SortHelper

  before_action :set_query_expansion,
                only: [:show, :edit, :update, :destroy]

  def index
    sort_init([["source", "asc"], ["destination", "asc"]])
    sort_update(["source", "destination", "created_at", "updated_at"])

    @request = FullTextSearch::QueryExpansionRequest.new(request_params)
    @n_expansions = FtsQueryExpansion.count
    @paginator = Paginator.new(@n_expansions, per_page_option, params["page"])
    @expansions =
      FtsQueryExpansion
        .order(sort_clause)
        .offset(@paginator.offset)
        .limit(@paginator.per_page)
  end

  def show
  end

  def new
    @query_expansion = FtsQueryExpansion.new
  end

  def create
    @query_expansion = FtsQueryExpansion.new(query_expansion_params)
    if @query_expansion.save
      notice = l(:notice_successful_create)
      if params[:continue]
        redirect_to new_fts_query_expansion_path,
                    notice: notice
      else
        redirect_to fts_query_expansions_path,
                    notice: notice
      end
    else
      render :new
    end
  end

  def update
    if @query_expansion.update(query_expansion_params)
      redirect_to @query_expansion, notice: l(:notice_successful_update)
    else
      render :edit
    end
  end

  def destroy
    @query_expansion.destroy
    redirect_to fts_query_expansions_url, notice: l(:notice_successful_delete)
  end

  private
  def set_query_expansion
    @query_expansion = FtsQueryExpansion.find(params[:id])
  end

  def request_params
    params.permit(:query)
  end

  def query_expansion_params
    params.require(:fts_query_expansion).permit(:source, :destination)
  end
end
