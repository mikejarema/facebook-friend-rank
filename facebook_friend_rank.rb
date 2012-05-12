$: << File.dirname(__FILE__)

require 'atomic'
require 'json'

require 'eventmachine'
require 'em-http-request'

require 'cacheable_lookup'

class FacebookFriendRank < CacheableLookup
  
  def response(env)
    id = params['id']
    token = params['token']

    # Grab cached sort order
    sort_order = cache.get(cache_key(id))

    # Compute and cache sort order if not already cached
    unless sort_order
      # Compute
      sort_order = compute_results(id, token)

      # Cache
      cache.set(cache_key(id), sort_order, CACHE_TTL)
    end

    [200, {'Content-Type' => 'application/json'}, sort_order]
  end

  def cache_key(id)
    "friend_sort::#{id}"
  end

  def compute_results(id, token)
    fiber = Fiber.current

    resolver = Generator.new(id, token)

    resolver.callback do |r|
      fiber.resume(r)
    end

    resolver.errback do |r|
      fiber.resume(r)
    end

    computed_results = Fiber.yield

    raise resp if computed_results.is_a?(Exception)

    computed_results
  end



  # Given an FB user ID and valid token, this class 'sorts' friends in order
  # of decreasing recent engagement.
  #
  # Basically in the recent history of the current user's feed, who appeared the
  # most often.

  FEED_DEPTH = 5   # Number of pages to inspect in the user's feed
  PER_PAGE =   100 # Number of feed items per page
  CALL_URL =   "https://graph.facebook.com/me/feed?access_token=%{token}&limit=#{PER_PAGE}"

  class Generator
    include EM::Deferrable

    def initialize(id, token)
      pending_calls = Atomic.new(FEED_DEPTH)
      calls =         Atomic.new([
        CALL_URL % {token: token}
      ])
      @friend_counts = Atomic.new({})

      timer = EM.add_periodic_timer(0.1) do
        if !calls.value.empty?
          batch = []
          
          calls.update do |v|
            batch = v.dup
            []
          end

          batch.each do |call|
            puts call

            http = EM::HttpRequest.new(call).get

            http.callback do
              data = JSON.parse(http.response)

              pending_calls.update {|v| v - 1}

              if pending_calls.value > 0 && data['paging'] && data['paging']['next']
                calls.update {|v| v << data['paging']['next']}

              else
                pending_calls.update { 0 }

              end

              process_data(data['data'])

              if pending_calls.value <= 0
                timer.cancel
                @friend_counts.update {|v| v.delete(id.to_i); v}
                self.succeed @friend_counts.value
              end
            end

            http.errback do |data|
              timer.cancel
              self.fail Exception.new(data)
            end
          end # batch.each


        end # if !calls.value.empty

      end # timer

    end # initialize

    def process_data(data)

      data.each do |item|

        case item['type']
        when "status"
          process_status(item)
        when "link"
          process_link(item)
        else
          puts "Cannot process #{item['type']}"
        end

        if item['comments'] && item['comments']['count']
          process_comments(item['comments'])
        end

      end # data.each

    end # process_data

    def process_link(link)
      ids = []

      ids << link['from']['id'] if link['from'] && link['from']['id']
      ids << link['to']['id'] if link['to'] && link['to']['id']
      ids << extract_ids_from_tags(link, 'message_tags')

      update_friend_counts(ids)
    end # process_link

    def process_status(status)
      ids = []

      ids << status['from']['id'] if status['from'] && status['from']['id']
      ids << extract_ids_from_tags(status, 'story_tags')

      update_friend_counts(ids)
    end # process_status

    def process_comments(comments)
      if comments['data']
        ids = []
        comments['data'].each {|i| ids << i['from']['id']}
        update_friend_counts(ids)
      end
    end # process_comments

    def extract_ids_from_tags(item, tag_type)
      item[tag_type].map do |k,v| 
        v.is_a?(Enumerable) ? v.map{|i| i['id']} : v
      end if item[tag_type]
    end # extract_ids_from_tags

    def update_friend_counts(ids)
      unless ids.empty?
        ids = ids.flatten.compact.map{|i| i.to_i}

        @friend_counts.update do |v|
          ids.each{|i| v[i] = v[i].to_i + 1}
          v
        end
      end
    end # update_friend_counts

  end

end
