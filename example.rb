require 'rubygems'
require 'sinatra'
require 'active_support/json'
require 'net/http'
require 'yaml'

configure do
  opts = YAML.load_file( File.expand_path('../settings.yml', __FILE__))
  opts.each do |key, value|
    set key.to_sym, value
  end
  # setting one option
  # set :my_option, 'value'
end

get '/' do

  # 1. redirect to authorize url
  unless code = params["code"]
    dialog_url = "#{settings.fidor_oauth_url}/authorize?client_id=#{settings.client_id}&redirect_uri=#{CGI::escape(settings.app_url)}&state=1234&response_type=code"
    redirect dialog_url
  end

  # 2. get the access token, with code returned from auth dialog above
  token_url = URI("#{settings.fidor_oauth_url}/token")
  # GET and parse access_token response json
  res = Net::HTTP.post_form(token_url, 'client_id' => settings.client_id,
                                       'redirect_uri' => CGI::escape(settings.app_url),
                                       'code' =>code,
                                       'client_secret'=>settings.client_secret,
                                       'grant_type'=>'authorization_code')

  resp = ActiveSupport::JSON.decode(res.body)

  # GET current user
  usr_url = "#{settings.fidor_api_url}/users/current?access_token=#{resp['access_token']}"
  user = ActiveSupport::JSON.decode( Net::HTTP.get URI(usr_url) )
  account_url = "#{settings.fidor_api_url}/accounts?access_token=#{resp['access_token']}"
  "<h2>Hello #{user['email']}</h2>
   <i>May i present the access token response:</i>
   <blockquote>#{resp.inspect}</blockquote>
   <p>Now use the access token in <br> <a href='#{account_url}'>#{account_url}</a></p>
   "
end