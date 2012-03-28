# encoding: utf-8

# Task sink
# Binds PULL socket to tcp://localhost:5558
# Collects results from task_workers via that socket

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

# Prepare our context and socket
context = XS::Context.create()
receiver = context.socket(XS::PULL)
receiver.bind("tcp://*:5558")

# Wait for start of batch
receiver.recv_string('')
puts 'Sink started'
tstart = Time.now

# Process 100 confirmations
100.times do |task_nbr|
  receiver.recv_string('')
  $stdout << ((task_nbr % 10 == 0) ? ':' : '.')
  $stdout.flush
end

# Calculate and report duration of batch
tend = Time.now
total_msec = (tend-tstart) * 1000
puts "Total elapsed time: #{total_msec} msec"

