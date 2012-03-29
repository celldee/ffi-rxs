# encoding: utf-8

#   Task vent to be used in conjunction with task_worker.rb
#   and task_sink.rb
#   Binds PUSH socket to tcp://localhost:5557
#   Sends batch of tasks to task_workers via that socket

require File.join(File.dirname(__FILE__), '..', 'lib', 'ffi-rxs')

context = XS::Context.create()

# Socket to send messages on
sender = context.socket(XS::PUSH)
sender.bind("tcp://*:5557")

puts "Press enter when the workers are ready..."
$stdin.read(1)
puts "Sending tasks to workers..."

# The first message is "0" and signals start of batch
sender.send_string('0')

# Send 100 tasks
total_msec = 0  # Total expected cost in msecs
100.times do
  workload = rand(100) + 1
  total_msec += workload
  $stdout << "#{workload}."
  sender.send_string(workload.to_s)
end

puts "Total expected cost: #{total_msec} msec"
Kernel.sleep(1)  # Give Crossroads time to deliver

