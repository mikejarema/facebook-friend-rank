$: << File.dirname(__FILE__)

require 'atomic'
require 'json'

require 'eventmachine'
require 'em-http-request'

require 'cacheable_lookup'

class FacebookFriendRank < CacheableLookup

  PROGRESSIVE_UPDATE_TTL = 30 # seconds

  def response(env)
    id =          params['id']
    token =       params['token']
    progressive = !params.has_key?('async') || params['async'].downcase == 'true' # async by default
    @verbose =    params.has_key?('verbose') && params['verbose'].downcase == 'true'

    # Grab cached sort order
    sort_order = cache.get(cache_key(id))

    # Compute and cache sort order if not already cached
    sort_order = compute_and_cache_results(id, token, progressive) unless sort_order

    [200, {'Content-Type' => 'application/json'}, sort_order]
  end

  def cache_key(id)
    "friend_rank::#{id}"
  end

  def compute_and_cache_results(id, token, progressive)
    fiber = Fiber.current

    resolver = Generator.new(id, token, :verbose => @verbose)

    done = Atomic.new(false)

    progress = Atomic.new(nil)

    resolver.callback do |r|
      puts "Completed friend rank for #{id}"
      done.value { true }
      cache.set(cache_key(id), r, CACHE_TTL)
      fiber.resume(r) if fiber.alive?
    end

    resolver.errback do |r|
      puts "Failure (#{r.class}) on friend rank for #{id}:"
      puts "#{r}"
      fiber.resume(r) if fiber.alive?
    end

    resolver.onupdate do |r|
      if !done.value && (!progress.value || r[:progress] > progress.value)
        progress.update{r[:progress]}
        cache.set(cache_key(id), r, PROGRESSIVE_UPDATE_TTL)
      end
      fiber.resume(r) if progressive && fiber.alive?
    end

    computed_results = Fiber.yield

    raise computed_results if computed_results.is_a?(Exception)

    computed_results
  end



  # Given an FB user ID and valid token, this class 'sorts' friends in order
  # of decreasing recent engagement.
  #
  # Basically in the recent history of the current user's feed, who appeared the
  # most often.

  FEED_DEPTH = 5   # Number of pages to inspect in the user's feed
  PER_PAGE =   100 # Number of feed items per page
  CALL_URL =   "https://graph.facebook.com/me/feed?access_token=%s&limit=#{PER_PAGE}"

  class Generator
    include EM::Deferrable

    def initialize(id, token, options = {})
      @onupdate_callbacks = []

      pending_calls = Atomic.new(FEED_DEPTH)
      calls =         Atomic.new([
        CALL_URL % token
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
            y call

            http = EM::HttpRequest.new(call).get

            http.callback do
              data = JSON.parse(http.response)

              if pending_calls.value > 1 && data['paging'] && data['paging']['next']
                calls.update {|v| v << data['paging']['next']}

              else
                pending_calls.update { 0 }

              end

              y data

              process_data(data['data'])

              pending_calls.update {|v| v - 1}

              if pending_calls.value <= 0
                timer.cancel
                @friend_counts.update {|v| v.delete(id.to_i); v}
                self.succeed({:data => @friend_counts.value, :progress => 1.0})
              end
            end

            http.errback do
              timer.cancel
              self.fail http.error
            end
          end # batch.each


        end # if !calls.value.empty

        @onupdate_callbacks.each do |c| 
          c.call({
            :data => @friend_counts.value, 
            :progress => (FEED_DEPTH - pending_calls.value) / FEED_DEPTH.to_f
          })
        end

      end # timer

    end # initialize

    def onupdate(&block)
      @onupdate_callbacks << block
    end

    def process_data(data)

      data.each do |item|
        unless ['status', 'link', 'video', 'photo', 'checkin'].include?(item['type'])
          puts "Additional processing req'd on #{item['type']}?"
          y item
        end

        process_common(item)
        process_comments(item['comments']) if item['comments'] && item['comments']['count'] > 0
        process_likes(item['likes'])       if item['likes']    && item['likes']['count']    > 0
      end

    end

    def process_common(item)
      ids = []
      
      ids << item['from']['id'] if item['from'] && item['from']['id']

      # To metadata is either a single entry or an array, handle both
      ids << item['to']['id'] if item['to'] && item['to']['id']
      ids << item['to']['data'].map{|i| i['id']}  if item['to'] && item['to']['data']

      # Handle *_tags payloads
      item.keys.each do |k|
        ids << extract_ids_from_tags(item, k) if k =~ /_tags$/ 
      end

      update_friend_counts(ids)
    end

    def process_comments(comments)
      if comments['data']
        ids = []
        comments['data'].each {|i| ids << i['from']['id']}
        update_friend_counts(ids)
      end
    end

    def process_likes(likes)
      if likes['data']
        ids = []
        likes['data'].each {|i| ids << i['id']}
        update_friend_counts(ids)
      end
    end

    def extract_ids_from_tags(item, tag_type)
      item[tag_type].map do |k,v| 
        v.is_a?(Enumerable) ? v.map{|i| i['id']} : v
      end if item[tag_type]
    end

    def update_friend_counts(ids)
      unless ids.empty?
        ids = ids.flatten.compact.map{|i| i.to_i}

        @friend_counts.update do |v|
          ids.each{|i| v[i] = v[i].to_i + 1}
          v
        end
      end
    end

  end

end
