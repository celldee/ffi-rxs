# encoding: utf-8

# request.rb

# This example is used in conjunction with reply.rb. Run this program in
# a terminal/console window and then run reply.rb in another terminal/console
# window and observe the output.
#
# Usage: ruby request.rb
#

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

ctx = XS::Context.create()
socket = ctx.socket(XS::REQ)
socket.connect("tcp://127.0.0.1:5000")
 
for i in 1..10
  msg = "msg #{i.to_s}"
  socket.send_string(msg)
  puts "Sending: " + msg
  socket.recv_string(msg_in = '')
  puts "Received: " + msg_in
end
