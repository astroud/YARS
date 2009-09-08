require File.dirname(__FILE__) + '/../test_helper'
require 'user_controller'

# Re-raise errors caught by the controller.
class UserController; def rescue_action(e) raise e end; end

class UserControllerTest < Test::Unit::TestCase
  include ApplicationHelper
  fixtures :users
  
  def setup
    @controller = UserController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    # This user is initially valid, but we may change its attributes.
    @valid_user = users(:valid_user)
  end

  # Make sure the registration page responds with the proper form.
  def test_registration_page
    get :register
    title = assigns(:title)
    assert_equal "Register", title
    assert_response :success
    assert_template "register"
    
    # Test the form and all its tags. 
    assert_tag "form", :attributes => { :action => "/user/register", 
                                        :method => "post" } 
    assert_tag   "input", 
                :attributes => { :name => "user[screen_name]", 
                                 :type => "text", 
                                 :size => User::SCREEN_NAME_SIZE, 
                                 :maxlength => User::SCREEN_NAME_MAX_LENGTH } 
    assert_tag   "input", 
                :attributes => { :name => "user[email]", 
                                 :type => "text", 
                                 :size => User::EMAIL_SIZE, 
                                 :maxlength => User::EMAIL_MAX_LENGTH } 
    assert_tag   "input", 
                :attributes => { :name => "user[password]", 
                                 :type => "password", 
                                 :size => User::PASSWORD_SIZE, 
                                 :maxlength => User::PASSWORD_MAX_LENGTH } 
    assert_tag   "input", :attributes => { :type => "submit", 
                                          :value => "Register!" } 
  end
  
  # Test a valid registration. 
  def test_registration_success 
    post :register, :user => { :screen_name => "new_screen_name", 
                                :email       => "valid@example.com", 
                               :password     => "long_enough_password" } 
    # Test assignment of user. 
    user = assigns(:user) 
    assert_not_nil user 
    # Test new user in database. 
    new_user = User.find_by_screen_name_and_password(user.screen_name, 
                                                     user.password) 
    assert_equal new_user, user 
    # Test flash and redirect. 
    assert_equal "User #{new_user.screen_name} created!", flash[:notice] 
    assert_redirected_to :action => "index" 
    
    # Make sure user is logged in properly.
    assert logged_in?
    assert_equal user.id, session[:user_id]
  end 
  
  # Test an invalid registration 
  def test_registration_failure 
    post :register, :user => { :screen_name => "aa/noyes", 
                               :email => "anoyes@example,com", 
                               :password => "sun" } 
    assert_response :success 
    assert_template "register" 
    # Test display of error messages. 
    assert_tag "div", :attributes => { :id => "errorExplanation", 
                                       :class => "errorExplanation" } 
    # Assert that each form field has at least one error displayed. 
    assert_tag "li", :content => /Screen name/ 
    assert_tag "li", :content => /Email/ 
    assert_tag "li", :content => /Password/ 
    
    # Test to see that the input fields are being wrapped with the correct div. 
    error_div = { :tag => "div", :attributes => { :class => "fieldWithErrors" } } 
    
    assert_tag "input", 
               :attributes => { :name => "user[screen_name]", 
                                 :value => "aa/noyes" }, 
               :parent => error_div 
    assert_tag "input", 
               :attributes => { :name => "user[email]", 
                                 :value => "anoyes@example,com" }, 
               :parent => error_div 
    assert_tag "input", 
               :attributes => { :name => "user[password]", 
                                 :value => "sun" }, 
               :parent => error_div 
  end   
  
  # Make sure the login page works and has the right fields.
  def test_login_page
    get :login
    title = assigns(:title)
    assert_equal "Log in to RailsSpace", title
    assert_response :success
    assert_template "login"
    assert_tag "form", :attributes => { :action => "/user/login", 
                                        :method => "post" }
    assert_tag "input",
               :attributes => { :name => "user[screen_name]",
                                :type => "text", 
                                :size => User::SCREEN_NAME_SIZE,
                                :maxlength => User::SCREEN_NAME_MAX_LENGTH }
    assert_tag "input", 
               :attributes => { :name => "user[password]",
                                :type => "password",
                                :size => User::PASSWORD_SIZE,
                                :maxlength => User::PASSWORD_MAX_LENGTH }
    assert_tag "input", :attributes => { :type => "submit",
                                         :value => "Login!" }
  end
  
  # Test a valid login.
  def test_login_success
    try_to_login @valid_user
    assert logged_in?
    assert_equal @valid_user.id, session[:user_id]
    assert_equal "User #{@valid_user.screen_name} logged in!", flash[:notice]
    assert_response :redirect
    assert_redirected_to :action => "index"
  end
  
  # Test a login with invalid screen name.
  def test_login_failure_with_nonexistent_screen_name
    invalid_user = @valid_user
    invalid_user.screen_name = "no such user"
    try_to_login invalid_user
    assert_template "login"
    assert_equal "Invalid screen name/password combination", flash[:notice]
    # Make sure screen_name will be redisplayed, but not the password.
    user = assigns(:user)
    assert_equal invalid_user.screen_name, user.screen_name
    assert_nil user.password
  end

  # Test a login with invalid password.
  def test_login_failure_with_wrong_password
    invalid_user = @valid_user
    # Construct an invalid password.
    invalid_user.password += "baz"
    try_to_login invalid_user
    assert_template "login"
    assert_equal "Invalid screen name/password combination", flash[:notice]
    # Make sure screen_name will be redisplayed, but not the password.
    user = assigns(:user)
    assert_equal invalid_user.screen_name, user.screen_name
    assert_nil user.password
  end
  
  # Test the logout function.
  def test_logout
    try_to_login @valid_user
    assert logged_in?
    get :logout
    assert_response :redirect
    assert_redirected_to :action => "index", :controller => "site"
    assert_equal "Logged out", flash[:notice]
    assert !logged_in?
  end
  
  # Test the navigation menu after login.
  def test_navigation_logged_in
    authorize @valid_user
    get :index
    assert_tag "a", :content => /Logout/,
               :attributes => { :href => "/user/logout" } 
    assert_no_tag "a", :content => /Register/    
    assert_no_tag "a", :content => /Login/
  end
  
  # Test index page for unauthorized user.
  def test_index_unauthorized
    # Make sure the before_filter is working.
    get :index
    assert_response :redirect
    assert_redirected_to :action => "login"
    assert_equal "Please log in first", flash[:notice]
  end
  
  # Test index page for authorized user.
  def test_index_authorized
    authorize @valid_user
    get :index
    assert_response :success
    assert_template "index"
  end
  
  # Test forward back to protected page after login.
  def test_login_friendly_url_forwarding
    # Get a protected page.
    get :index
    assert_response :redirect
    assert_redirected_to :action => "login"
    try_to_login @valid_user
    assert_response :redirect
    assert_redirected_to :action => "index"  
    # Make sure the forwarding url has been cleared.
    assert_nil session[:protected_page]
  end
  
  # Test forward back to protected page after register.
  def test_register_friendly_url_forwarding
    # Get a protected page.
    get :index
    assert_response :redirect
    assert_redirected_to :action => "login"
    post :register, :user  => { :screen_name => "new_screen_name",
                                :email       => "valid@example.com",
                                :password    => "long_enough_password" }
    assert_response :redirect
    # This is a hack.  See http://www.ruby-forum.com/topic/69760
    assert_redirected_to :action => "index"
    # Make sure the forwarding url has been cleared.
    assert_nil session[:protected_page]  
  end
  
  private
  
  # Try to log a user in using the login action.
  def try_to_login(user)
    post :login, :user => { :screen_name => user.screen_name,
                            :password    => user.password }
  end
  
  # Authorize a user.
  def authorize(user)
    @request.session[:user_id] = user.id
  end
end