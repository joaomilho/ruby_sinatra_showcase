require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'active_support/json'
require 'net/http'
require 'yaml'
require 'erb'

enable :sessions

configure do
  opts = YAML.load_file( File.expand_path('../settings.yml', __FILE__))
  opts.each do |key, value|
    set key.to_sym, value
  end
end

configure :development do
  register Sinatra::Reloader
end

helpers do
  def logged_in?
    @access_token
  end
  # get the current user information. Should also be persisted in session
  def current_user
    if logged_in?
      usr_url = "#{settings.fidor_api_url}/users/current?access_token=#{session['access_token']}"
      @user = ActiveSupport::JSON.decode( Net::HTTP.get URI(usr_url) )
    end
  end
end

before do
  @access_token = session['access_token']
end

get '/' do
  erb :index
end

get '/transactions' do
  url = "#{settings.fidor_api_url}/transactions?access_token=#{session['access_token']}"
  res = ActiveSupport::JSON.decode( Net::HTTP.get URI(url))
  if res.is_a?(Hash) && res['error']
    @error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
  else
    @transactions = res
  end
  erb :transactions
end

get '/sepa_credit_transfers' do
  url = "#{settings.fidor_api_url}/sepa_credit_transfers?access_token=#{session['access_token']}"
  res = ActiveSupport::JSON.decode( Net::HTTP.get URI(url))
  if res.is_a?(Hash) && res['error']
    @error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
  else
    @transfers = res
  end
  erb :sepa_credit_transfers
end

get '/internal_transfers' do
  url = "#{settings.fidor_api_url}/internal_transfers?access_token=#{session['access_token']}"
  res = ActiveSupport::JSON.decode( Net::HTTP.get URI(url))
  if res.is_a?(Hash) && res['error']
    @error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
  else
    @transfers = res
  end
  erb :internal_transfers
end

get '/logout' do
  session.destroy
  redirect '/'
end

# 1. Redirect the user to the fidor login
get '/login' do
  # oAuth state param should be unique per user/request, in here only for the showcase
  state_param = 'keo83j4jdu35kd245'
  dialog_url = "#{settings.fidor_oauth_url}/authorize?client_id=#{settings.client_id}&redirect_uri=#{CGI::escape(settings.oauth_callback_url)}&state=#{state_param}&response_type=code"
  redirect dialog_url
end

# 2. get the access token, with code returned from auth dialog above
get '/oauth_callback' do
  raise "Redirect from fidor does not have the code param" unless params["code"]
  raise "Redirect from fidor does not have the state param" unless params["state"]

  token_url = URI("#{settings.fidor_oauth_url}/token")
  # GET and parse access_token response json
  request = Net::HTTP.post_form(token_url, client_id: settings.client_id,
                                       redirect_uri: CGI::escape(settings.oauth_callback_url),
                                       code: params["code"],
                                       client_secret: settings.client_secret,
                                       grant_type: 'authorization_code')
  response = ActiveSupport::JSON.decode(request.body)
  # puts response.inspect
  if response['state'] != params["state"]
    raise "State param does not match request may be tempered"
  else
    session[:access_token] = response['access_token']
    session[:expires] = Time.now + response['expires_in']
  end
  redirect '/'
end