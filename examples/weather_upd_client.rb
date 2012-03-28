# encoding: utf-8

# weather_upd_client.rb

# This example is used in conjunction with weather_upd_server.rb.
# Run this program in a terminal/console window and then run
# weather_upd_server.rb in another terminal/console window and
# observe the output.
#
# This program subscribes to a feed of weather updates published
# by weather_upd_server.rb, collects the first 100 updates that
# match the subscription filter and displays the average temperature
# for that zipcode.
#
# Usage: ruby weather_upd_client.rb [zip code (default=10001)]
#
# If you supply a zip code argument then the maximum value that will
# be recognized is 11000.

require 'ffi-rxs'

COUNT = 100

context = XS::Context.new()

# Socket to talk to server
puts "Collecting updates from weather server..."
subscriber = context.socket(XS::SUB)
subscriber.connect("tcp://127.0.0.1:5556")

# Subscribe to zipcode, default is NYC, 10001
filter = ARGV.size > 0 ? ARGV[0] : "10001"
subscriber.setsockopt(XS::SUBSCRIBE, filter)

# Process 100 updates
total_temp = 0
1.upto(COUNT) do |update_nbr|
  s = ''
  subscriber.recv_string(s)
  
  zipcode, temperature, relhumidity = s.split.map(&:to_i)
  total_temp += temperature
  puts "Update #{update_nbr.to_s}: #{temperature.to_s}F"
end

puts "Average temperature for zipcode '#{filter}' was #{total_temp / COUNT}F"

