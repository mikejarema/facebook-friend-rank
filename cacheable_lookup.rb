require 'goliath'
require 'dalli'
require 'em-synchrony'

class EventMachine::Synchrony::ConnectionPool
  attr_accessor :reserved, :available, :pending
end

# CacheableLookup
# ===============
#
# This is an abstract class giving goliath handlers easy access to a memcache
# client using the instance variable 'cache'.  
#
# CacheableLookup will intercept the 'force' param and if set will force all cache
# calls to bypass the the cache.
#

class CacheableLookup < Goliath::API
  CACHE_TTL = 60 * 60 # 1 hour

  # DummyClient says 'nil' to everything
  class DummyClient
    def method_missing(*args);    nil;     end
    def get_multi(*args)          {};      end
    def respond_to?(*args);       nil;     end
  end
  
  # DalliWrapper is tolerant of failed gets & sets
  class DalliWrapper < Dalli::Client
    def get(key, options=nil)
      super(key, options)
    rescue Exception => e
      puts "Memcache failed: #{e.class} (#{e.message})"
      nil
    end

    def get_multi(*keys)
      super(*keys)
    rescue Exception => e
      puts "Memcache failed: #{e.class} (#{e.message})"
      {}
    end
    
    def set(key, value, ttl=nil, options=nil)
      super(key, value, ttl, options)
    rescue Exception => e
      puts "Memcache failed: #{e.class} (#{e.message})"
      nil
    end
  end
  
  @@cache_pool = EventMachine::Synchrony::ConnectionPool.new(size: 20) do
    # NOTE: in development the MEMCACHIER references nil out (assumes localhost & unauthenticated cache)
    DalliWrapper.new(
      ENV['MEMCACHIER_SERVERS'], 
      username: ENV['MEMCACHIER_USERNAME'], password: ENV['MEMCACHIER_PASSWORD'], :expires_in => CACHE_TTL,
      async: false  # <-- NOTE: async disabled, it doesn't work in a Fiber (as req'd by facebook_friend_rank.rb)
    )
  end
  
  def cache
    if !params['force']
      @@cache_pool
    else
      @dummy_cache ||= DummyClient.new
    end
  end

  def self.cache_pool
    @@cache_pool
  end

end
