# encoding: utf-8

# Durable publisher to be used in conjunction with durable_sub.rb
# Justin Case <justin@playelite.com>

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

context = XS::Context.create()

# Subscriber tells us when it's ready here
sync = context.socket(XS::PULL)
sync.bind("tcp://127.0.0.1:5564")

# We send updates via this socket
publisher = context.socket(XS::PUB)
publisher.bind("tcp://127.0.0.1:5565")

# Wait for synchronization request
sync.recv_string(sync_request = '')

# Now broadcast exactly 10 updates with pause
10.times do |update_number|
  message = sprintf("Update %d", update_number)
  puts "Sending: " + message
  publisher.send_string(message)
  sleep(1)
end
  
publisher.send_string("END")

sync.close
publisher.close
context.terminate

