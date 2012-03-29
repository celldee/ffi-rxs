# encoding: utf-8

# req_rep_poll.rb
#
# It illustrates the use of xs_poll(), as wrapped by the Ruby library,
# for detecting and responding to read and write events recorded on sockets.
# It also shows how to use XS::NO_BLOCK/XS::DONTWAIT for non-blocking send
# and receive.

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')


def assert(rc)
  raise "Last API call failed at #{caller(1)}" unless rc >= 0
end

link = "tcp://127.0.0.1:5554"

begin
  ctx = XS::Context.create()
  s1 = ctx.socket(XS::REQ)
  s2 = ctx.socket(XS::REP)
rescue ContextError => e
  STDERR.puts "Failed to allocate context or socket!"
  raise
end

assert(s1.setsockopt(XS::LINGER, 100))
assert(s2.setsockopt(XS::LINGER, 100))

assert(s1.connect(link))
assert(s2.bind(link))

poller = XS::Poller.new
poller.register_readable(s2)
poller.register_writable(s1)

start_time = Time.now
@unsent = true

until @done do
  assert(poller.poll_nonblock)

  # send the message after 5 seconds
  if Time.now - start_time > 5 && @unsent
    payload = "#{ '3' * 1024 }"

    puts "sending payload nonblocking"
    assert(s1.send_string(payload, XS::NonBlocking))
    @unsent = false
  end

  # check for messages after 1 second
  if Time.now - start_time > 1
    poller.readables.each do |sock|
      received_msg = ''
      assert(sock.recv_string(received_msg, XS::NonBlocking))

      puts "message received [#{received_msg}]"
      @done = true
    end
  end
end

puts "executed in [#{Time.now - start_time}] seconds"

assert(s1.close)
assert(s2.close)

ctx.terminate

