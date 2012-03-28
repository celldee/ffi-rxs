# encoding: utf-8

# weather_upd_server.rb

# This example is used in conjunction with weather_upd_client.rb.
# Run this program in a terminal/console window and then run
# weather_upd_client.rb in another terminal/console window and
# observe the output.
#
# This program publishes a feed of random weather updates containing
# random zip codes up to a maximum value of 11000.
#
# Usage: ruby weather_upd_server.rb
#
# To stop the program terminate the process with Ctrl-C or another
# method of your choice.
#


require 'ffi-rxs'

context = XS::Context.new()
publisher = context.socket(XS::PUB)
publisher.bind("tcp://127.0.0.1:5556")

while true
  # Get values that will fool the boss
  zipcode = rand(11000)
  temperature = rand(215) - 80
  relhumidity = rand(50) + 10

  update = "%05d %d %d" % [zipcode, temperature, relhumidity]
  puts update
  publisher.send_string(update)
end

