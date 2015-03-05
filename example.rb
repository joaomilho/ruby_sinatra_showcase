require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'net/http'
require 'yaml'
require 'erb'
require 'httparty'

enable :sessions

configure do
  # load all files from /lib
  $LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib")
  Dir.glob("#{File.dirname(__FILE__)}/lib/*.rb") { |lib|
    require File.basename(lib, '.*')
  }
  # Read the config
  opts = YAML.load_file( File.expand_path('../settings.yml', __FILE__))
  # set base api url for all api request in the lib
  Fidor::Resource.base_uri(opts['fidor_api_url'])
  # Still need the settings for the oAuth login
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
      @user ||= HTTParty.get( "#{settings.fidor_api_url}/users/current",
                              headers: { 'Authorization' => "Bearer #{session['access_token']}"} )
    else
      nil
    end
  end
end

before do
  @access_token = session['access_token']
  @flash = session.delete('flash')
end

get '/' do
  erb :index
end

get '/transactions' do
  @transactions , @error = Fidor::Transaction.find_all(session['access_token'])
  erb :transactions
end

get '/sepa_credit_transfers' do
  @filter = params['filter'] || {}
  @transfers, @error = Fidor::SepaCreditTransfer.find_all( session['access_token'],
                                                           filter: @filter )
  erb :sepa_credit_transfers
end

get '/internal_transfers' do
  @transfers, @error = Fidor::InternalTransfer.find_all(session['access_token'])
  erb :internal_transfers
end

get '/sepa_mandates' do
  @filter = params['filter'] || {}
  @mandates, @error = Fidor::SepaMandate.find_all( session['access_token'],
                                                    filter: @filter )
  erb :sepa_mandates
end

# show form
get '/sepa_mandates/new' do
  erb :sepa_mandates_new
end

post '/sepa_mandates' do

  # find and use the first customer. Could be done in GET /new and added to a select-box
  begin
    res = HTTParty.get( "#{settings.fidor_api_url}/customers",
                          headers: { 'Authorization' => "Bearer #{session['access_token']}"} )
    customer_id = res[0]['id']
  rescue
    @error = "Customer could not be found. Try logging in again."
  end
  # check account locked, balance_available, overdraft against the given amount
  # validate the data
  unless @error
    @mandate = params['mandate']
    @mandate['customer_id'] = customer_id
    # generate custom external_uid
    @mandate['external_uid'] = SecureRandom.hex(10)
    # random Mandate reference, needed for withdrawals later
    @mandate['mandate_reference'] = SecureRandom.hex(15)
    # set the valid_from_date to signature date
    @mandate['valid_from_date'] = @mandate['signature_date']
    # lets make it a recurring mandate
    @mandate['sequence'] = 'RCUR'

    response = HTTParty.post( "#{settings.fidor_api_url}/sepa_mandates",
                              body: {sepa_mandate: @mandate}.to_json,
                              headers: { 'Content-Type' => 'application/json',
                                         'Authorization' => "Bearer #{session['access_token']}"} )

    # check for success & handle errors
    if response.code != 200
      res = JSON.parse( response.body )
      if res.is_a?(Hash) && res['error']
        @error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
      else
        @error = "Unexpected error with response code #{response.code}"
      end
    end
  end

  if @error
    erb :sepa_mandates_new
  else
    session['flash'] = "Successfully created Mandate for: #{@mandate['remote_name']}."
    redirect '/sepa_mandates'
  end
end

# show form
get '/sepa_credit_transfers/new' do
  erb :sepa_credit_transfers_new
end

post '/sepa_credit_transfers' do

  # find and use the first account. Could be done in GET new and added to a select-box
  begin
    res = HTTParty.get( "#{settings.fidor_api_url}/accounts",
                          headers: { 'Authorization' => "Bearer #{session['access_token']}"} )
    account_id = res[0]['id']
  rescue
    @error = "Account could not be found. Try logging in again."
  end
  # check account locked, balance_available, overdraft against the given amount
  # validate the data
  unless @error
    @transfer = params['transfer']
    @transfer['account_id'] = account_id
    # generate custom external_uid
    @transfer['external_uid'] = SecureRandom.hex(10)
    # replace commas and clean everything but numbers/dots and convert the amount to cents
    @transfer['amount'] = (@transfer['plain_amount'].gsub(/,/, '.').gsub(/[^0-9,.]/, '').to_f * 100.0).to_i
    # use HTTParty gem since ruby stdlib really sucks
    response = HTTParty.post( "#{settings.fidor_api_url}/sepa_credit_transfers",
                              body: {sepa_credit_transfer: @transfer}.to_json,
                              headers: { 'Content-Type' => 'application/json',
                                         'Authorization' => "Bearer #{session['access_token']}"} )

    # check for success & handle errors
    if response.code != 200
      res = JSON.parse( response.body )
      if res.is_a?(Hash) && res['error']
        @error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
      else
        @error = "Unexpected error with response code #{response.code}"
      end
    end
  end

  if @error
    erb :sepa_credit_transfers_new
  else
    session['flash'] = "Successfully send: #{@transfer['amount']/100.0}€ to IBAN #{@transfer['remote_iban']}"
    redirect '/sepa_credit_transfers'
  end

end

get '/internal_transfers/new' do
  erb :internal_transfers_new
end

post '/internal_transfers' do

  # find and use the first account. Could be done in GET new and added to a select-box
  begin
    res = HTTParty.get( "#{settings.fidor_api_url}/accounts",
                        headers: { 'Authorization' => "Bearer #{session['access_token']}"} )
    account_id = res[0]['id']
  rescue
    @error = "Account could not be found. Try logging in again."
  end
  # check account locked, balance_available, overdraft against the given amount
  # validate the data
  unless @errors
    @transfer = params['transfer']
    @transfer['account_id'] = account_id
    # generate custom external_uid
    @transfer['external_uid'] = SecureRandom.hex(10)
    # replace commas and clean everything but numbers/dots and convert the amount to cents
    @transfer['amount'] = (@transfer['plain_amount'].gsub(/,/, '.').gsub(/[^0-9,.]/, '').to_f * 100.0).to_i
    # use HTTParty gem since ruby stdlib really sucks
    response = HTTParty.post( "#{settings.fidor_api_url}/internal_transfers",
                              body: {internal_transfer: @transfer}.to_json,
                              headers: { 'Content-Type' => 'application/json',
                                         'Authorization' => "Bearer #{session['access_token']}"} )

    # check for success & handle errors
    if response.code != 200
      res = JSON.parse( response.body )
      if res.is_a?(Hash) && res['error']
        @error = "Error Code #{res['error']['code']}: #{res['error']['message']}"
      else
        @error = "Unexpected error with response code #{response.code}"
      end
    end
  end

  if @error
    erb :internal_transfers_new
  else
    session['flash'] = "Successfully send: #{@transfer['amount']/100.0}€ to #{@transfer['receiver']}"
    redirect '/internal_transfers'
  end
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
  response = JSON.parse(request.body)
  # puts response.inspect
  if response['state'] != params["state"]
    raise "State param does not match request may be tempered"
  else
    session[:access_token] = response['access_token']
    session[:expires] = Time.now + response['expires_in']
  end
  redirect '/'
end