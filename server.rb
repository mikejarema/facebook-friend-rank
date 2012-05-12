$: << File.dirname(__FILE__)

require 'goliath'
require 'em-http/middleware/json_response'

require 'facebook_friend_rank'

class RackRoutes < Goliath::API

  # parse query params and auto format JSON response
  use Goliath::Rack::Params
  use Goliath::Rack::JSONP
  use Goliath::Rack::Render
  use Goliath::Rack::Formatters::JSON

  get "/ping" do
    run Proc.new { |env| [200, {'Content-Type' => 'text/plain'}, "OK"] }
  end

  get '/' do
    run FacebookFriendRank.new
  end

end
