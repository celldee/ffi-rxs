# encoding: utf-8

#   Task worker in Ruby
#   Connects PULL socket to tcp://localhost:5557
#   Collects workloads from task_vent via that socket
#   Connects PUSH socket to tcp://localhost:5558
#   Sends results to sink via that socket

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

context = XS::Context.create()

# Socket to receive messages on
receiver = context.socket(XS::PULL)
receiver.connect("tcp://localhost:5557")

# Socket to send messages to
sender = context.socket(XS::PUSH)
sender.connect("tcp://localhost:5558")

# Process tasks forever
while true
  
  receiver.recv_string(msec = '')
  # Simple progress indicator for the viewer
  $stdout << "#{msec}."
  $stdout.flush

  # Do the work
  sleep(msec.to_f / 1000)

  # Send results to sink
  sender.send_string("")
end

