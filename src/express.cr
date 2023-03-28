require "./constants.cr"

require "./express/client.cr"
require "./express/server.cr"

server = Express::Server.new
server.draw_routes
server.run
