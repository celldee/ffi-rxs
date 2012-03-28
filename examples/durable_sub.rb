# encoding: utf-8

# Durable subscriber to be used in conjunction with durable_pub.rb
# Justin Case <justin@playelite.com>

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

context = XS::Context.create()

# Connect our subscriber socket
subscriber = context.socket(XS::SUB)
subscriber.setsockopt(XS::IDENTITY, "Hello")
subscriber.setsockopt(XS::SUBSCRIBE, "")
subscriber.connect("tcp://127.0.0.1:5565")

# Synchronize with publisher
sync = context.socket(XS::PUSH)
sync.connect("tcp://127.0.0.1:5564")
sync.send_string("")

# Get updates, exit when told to do so
loop do
  subscriber.recv_string(message = '')
  puts "Received: " + message
  if message == "END"
    break
  end
end

