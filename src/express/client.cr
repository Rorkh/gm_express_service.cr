require "redis"

module Express
  class Client
    def initialize
      @redis = Redis.new
    end

    def get(key)
      data = @redis.get(key)
      return data
    end

    # Because I'm dumb (?)
    def get_raw(key) : Bytes?
      data = @redis.get(key)
      return data.nil? ? nil : data.to_slice
    end

    def put(key, value)
      @redis.set(key, value, ex: Express::EXPIRATION)
    end
  end
end
