# encoding: utf-8

# reply.rb

# This example is used in conjunction with request.rb. Run this program in
# a terminal/console window and then run request.rb in another terminal/console
# window and observe the output.
#
# Usage: ruby reply.rb
#
# To stop the program terminate the process with Ctrl-C or another
# method of your choice.
#

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

ctx = XS::Context.create()
socket = ctx.socket(XS::REP)
socket.bind("tcp://127.0.0.1:5000")
 
while true do
  socket.recv_string(msg = '')
  puts "Got: " + msg
  socket.send_string(msg)
end
