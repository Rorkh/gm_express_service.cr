require "router"
require "json"
require "uuid"

require "compress/gzip"

module Express
  class Server
    include Router

    @client : Express::Client = Express::Client.new

    # Functions

    private def put_data(data : Bytes) : String
      id = UUID.random.to_s
      # Im not sure if it's good
      # https://stackoverflow.com/questions/47643509/how-to-store-bytes-sliceuint8-as-a-string-in-crystal
      # https://github.com/stefanwille/crystal-redis/issues/47 to see

      @client.put("size:#{id}", data.size * sizeof(UInt8))
      @client.put("data:#{id}", String.new(data))

      id
    end

    private def put_token(token)
      now = Time.local.to_unix
      @client.put("token:#{token}", now)
    end

    private def get_data(id) : Bytes?
      @client.get_raw("data:#{id}")
    end

    private def validate_request(token)
      return !@client.get("token:#{token}").nil?
    end

    private def get_size(id) : String?
      @client.get("size:#{id}")
    end

    # Routes

    def draw_routes
      get "/" do |context, params|
        context.response.redirect Express::WEBSITE
        context
      end

      get "/v1/revision" do |context, params|
        context.response.print({"revision" => Express::REVISION}.to_json)
        context
      end

      get "/v1/register" do |context, params|
        server_uuid = UUID.random.to_s
        client_uuid = UUID.random.to_s

        put_token server_uuid
        put_token client_uuid

        context.response.print({"server" => server_uuid, "client" => client_uuid}.to_json)
        context
      end

      get "/v1/read/:token/:id" do |context, params|
        if !validate_request(params["token"])
          context.response.respond_with_status(401)
          context
        end

        data = get_data(params["id"])
        if data.nil?
          context.response.respond_with_status(404, "No data found")
          context
        end

        context.response.content_type = "application/octet-stream"
        context.response.headers.add "Accept-Encoding", "gzip"

        if Express::COMPRESS
          io = IO::Memory.new
          gzip = Compress::Gzip::Writer.new(io)
          gzip.print data.not_nil!
          gzip.close
          io.rewind

          context.response.write io.to_slice
        else
          context.response.write data.not_nil!
        end

        context
      end

      get "/v1/size/:token/:id" do |context, params|
        if !validate_request(params["token"])
          context.response.respond_with_status(401)
          context
        end

        size = get_size(params["id"])
        if size.nil?
          context.response.respond_with_status(404, "Size not found")
          context
        end

        context.response.print({"size" => size.not_nil!.to_i}.to_json)
        context
      end

      post "/v1/write/:token" do |context, params|
        if !validate_request(params["token"])
          context.response.respond_with_status(401)
          context
        end

        data = context.request.body.not_nil!.gets_to_end.to_slice
        if data.size * sizeof(UInt8) > Express::MAX_DATA_SIZE
          context.response.respond_with_status(413, "Data exceeds maximum size of #{Express::MAX_DATA_SIZE}")
          context
        end

        id = put_data(data)
        context.response.print({"id" => id}.to_json)
        context
      end
    end

    # Run

    def run
      server = HTTP::Server.new(route_handler)
      server.bind_tcp 80
      server.listen
    end
  end
end
