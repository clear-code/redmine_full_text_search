require File.expand_path("../../test_helper", __FILE__)

class FtsQueryExpansionsControllerTest < ActionController::TestCase
  include PrettyInspectable

  fixtures :users

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_require_admin
    @request.session[:user_id] = nil
    get :index
    assert_response 302
  end
end
