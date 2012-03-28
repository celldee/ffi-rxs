
module XS

  module CommonSocketBehavior
    include XS::Util

    attr_reader :socket, :name

    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # +type+ can be one of XS::REQ, XS::REP, XS::PUB,
    # XS::SUB, XS::PAIR, XS::PULL, XS::PUSH, XS::XREQ, XS::REP,
    # XS::DEALER or XS::ROUTER.
    #
    # By default, this class uses XS::Message for manual
    # memory management. For automatic garbage collection of received messages,
    # it is possible to override the :receiver_class to use XS::ManagedMessage.
    #
    #  sock = Socket.create(Context.create, XS::REQ, :receiver_class => XS::ManagedMessage)
    #
    # Advanced users may want to replace the receiver class with their
    # own custom class. The custom class must conform to the same public API
    # as XS::Message.
    #
    # Creation of a new Socket object can return nil when socket creation
    # fails.
    #
    #  if (socket = Socket.new(context.pointer, XS::REQ))
    #    ...
    #  else
    #    STDERR.puts "Socket creation failed"
    #  end
    #
    def self.create context_ptr, type, opts = {:receiver_class => XS::Message}
      new(context_ptr, type, opts) rescue nil
    end

    # To avoid rescuing exceptions, use the factory method #create for
    # all socket creation.
    #
    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # +type+ can be one of XS::REQ, XS::REP, XS::PUB,
    # XS::SUB, XS::PAIR, XS::PULL, XS::PUSH, XS::XREQ, XS::REP,
    # XS::DEALER or XS::ROUTER.
    #
    # By default, this class uses XS::Message for manual
    # memory management. For automatic garbage collection of received messages,
    # it is possible to override the :receiver_class to use XS::ManagedMessage.
    #
    #  sock = Socket.new(Context.new, XS::REQ, :receiver_class => XS::ManagedMessage)
    #
    # Advanced users may want to replace the receiver class with their
    # own custom class. The custom class must conform to the same public API
    # as XS::Message.
    #
    # Creation of a new Socket object can raise an exception. This occurs when the
    # +context_ptr+ is null or when the allocation of the Crossroads socket within the
    # context fails.
    #
    #  begin
    #    socket = Socket.new(context.pointer, XS::REQ)
    #  rescue ContextError => e
    #    # error handling
    #  end
    #
    def initialize context_ptr, type, opts = {:receiver_class => XS::Message}
      # users may override the classes used for receiving; class must conform to the
      # same public API as XS::Message
      @receiver_klass = opts[:receiver_class]

      context_ptr = context_ptr.pointer if context_ptr.kind_of?(XS::Context)

      unless context_ptr.null?
        @socket = LibXS.xs_socket context_ptr, type
        if @socket && !@socket.null?
          @name = SocketTypeNameMap[type]
        else
          raise ContextError.new 'xs_socket', 0, ETERM, "Socket pointer was null"
        end
      else
        raise ContextError.new 'xs_socket', 0, ETERM, "Context pointer was null"
      end

      @longlong_cache = @int_cache = nil
      @more_parts_array = []
      @option_lookup = []
      populate_option_lookup

      define_finalizer
    end

    # Set the queue options on this socket.
    #
    # Valid +name+ values that take a numeric +value+ are:
    #  XS::HWM
    #  XS::SWAP (version 2 only)
    #  XS::AFFINITY
    #  XS::RATE
    #  XS::RECOVERY_IVL
    #  XS::MCAST_LOOP (version 2 only)
    #  XS::LINGER
    #  XS::RECONNECT_IVL
    #  XS::BACKLOG
    #  XS::RECOVER_IVL_MSEC (version 2 only)
    #  XS::RECONNECT_IVL_MAX (version 3 only)
    #  XS::MAXMSGSIZE (version 3 only)
    #  XS::SNDHWM (version 3 only)
    #  XS::RCVHWM (version 3 only)
    #  XS::MULTICAST_HOPS (version 3 only)
    #  XS::RCVTIMEO (version 3 only)
    #  XS::SNDTIMEO (version 3 only)
    #
    # Valid +name+ values that take a string +value+ are:
    #  XS::IDENTITY (version 2/3 only)
    #  XS::SUBSCRIBE
    #  XS::UNSUBSCRIBE
    #
    # Returns 0 when the operation completed successfully.
    # Returns -1 when this operation failed.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    #  rc = socket.setsockopt(XS::LINGER, 1_000)
    #  XS::Util.resultcode_ok?(rc) ? puts("succeeded") : puts("failed")
    #
    def setsockopt name, value, length = nil
      if 1 == @option_lookup[name]
        length = 8
        pointer = LibC.malloc length
        pointer.write_long_long value

      elsif 0 == @option_lookup[name]
        length = 4
        pointer = LibC.malloc length
        pointer.write_int value

      elsif 2 == @option_lookup[name]
        length ||= value.size

        # note: not checking errno for failed memory allocations :(
        pointer = LibC.malloc length
        pointer.write_string value
      end

      rc = LibXS.xs_setsockopt @socket, name, pointer, length
      LibC.free(pointer) unless pointer.nil? || pointer.null?
      rc
    end

    # Convenience method for checking on additional message parts.
    #
    # Equivalent to calling Socket#getsockopt with XS::RCVMORE.
    #
    # Warning: if the call to #getsockopt fails, this method will return
    # false and swallow the error.
    #
    #  message_parts = []
    #  message = Message.new
    #  rc = socket.recvmsg(message)
    #  if XS::Util.resultcode_ok?(rc)
    #    message_parts << message
    #    while more_parts?
    #      message = Message.new
    #      rc = socket.recvmsg(message)
    #      message_parts.push(message) if resulcode_ok?(rc)
    #    end
    #  end
    #
    def more_parts?
      rc = getsockopt XS::RCVMORE, @more_parts_array

      Util.resultcode_ok?(rc) ? @more_parts_array.at(0) : false
    end

    # Binds the socket to an +address+.
    #
    #  socket.bind("tcp://127.0.0.1:5555")
    #
    def bind address
      LibXS.xs_bind @socket, address
    end

    # Connects the socket to an +address+.
    #
    #  rc = socket.connect("tcp://127.0.0.1:5555")
    #
    def connect address
      rc = LibXS.xs_connect @socket, address
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option XS::LINGER.
    #
    # Returns 0 upon success *or* when the socket has already been closed.
    # Returns -1 when the operation fails. Check XS.errno for the error code.
    #
    #  rc = socket.close
    #  puts("Given socket was invalid!") unless 0 == rc
    #
    def close
      if @socket
        remove_finalizer
        rc = LibXS.xs_close @socket
        @socket = nil
        release_cache
        rc
      else
        0
      end
    end

    # Queues the message for transmission. Message is assumed to conform to the
    # same public API as #Message.
    #
    # +flags+ may take two values:
    # * 0 (default) - blocking operation
    # * XS::NonBlocking - non-blocking operation
    # * XS::SNDMORE - this message is part of a multi-part message
    #
    # Returns 0 when the message was successfully enqueued.
    # Returns -1 under two conditions.
    # 1. The message could not be enqueued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    def sendmsg message, flags = 0
      __sendmsg__(@socket, message.address, flags)
    end

    # Helper method to make a new #Message instance out of the +string+ passed
    # in for transmission.
    #
    # +flags+ may be XS::NonBlocking and XS::SNDMORE.
    #
    # Returns 0 when the message was successfully enqueued.
    # Returns -1 under two conditions.
    # 1. The message could not be enqueued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    def send_string string, flags = 0
      message = Message.new string
      send_and_close message, flags
    end

    # Send a sequence of strings as a multipart message out of the +parts+
    # passed in for transmission. Every element of +parts+ should be
    # a String.
    #
    # +flags+ may be XS::NonBlocking.
    #
    # Returns 0 when the messages were successfully enqueued.
    # Returns -1 under two conditions.
    # 1. A message could not be enqueued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    def send_strings parts, flags = 0
      return -1 if !parts || parts.empty?
      flags = NonBlocking if dontwait?(flags)

      parts[0..-2].each do |part|
        rc = send_string part, (flags | XS::SNDMORE)
        return rc unless Util.resultcode_ok?(rc)
      end

      send_string parts[-1], flags
    end

    # Send a sequence of messages as a multipart message out of the +parts+
    # passed in for transmission. Every element of +parts+ should be
    # a Message (or subclass).
    #
    # +flags+ may be XS::NonBlocking.
    #
    # Returns 0 when the messages were successfully enqueued.
    # Returns -1 under two conditions.
    # 1. A message could not be enqueued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    def sendmsgs parts, flags = 0
      return -1 if !parts || parts.empty?
      flags = NonBlocking if dontwait?(flags)

      parts[0..-2].each do |part|
        rc = sendmsg part, (flags | XS::SNDMORE)
        return rc unless Util.resultcode_ok?(rc)
      end

      sendmsg parts[-1], flags
    end

    # Sends a message. This will automatically close the +message+ for both successful
    # and failed sends.
    #
    # Returns 0 when the message was successfully enqueued.
    # Returns -1 under two conditions.
    # 1. The message could not be enqueued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    def send_and_close message, flags = 0
      rc = sendmsg message, flags
      message.close
      rc
    end

    # Dequeues a message from the underlying queue. By default, this is a blocking operation.
    #
    # +flags+ may take two values:
    #  0 (default) - blocking operation
    #  XS::NonBlocking - non-blocking operation
    #
    # Returns 0 when the message was successfully dequeued.
    # Returns -1 under two conditions.
    # 1. The message could not be dequeued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    # The application code is responsible for handling the +message+ object lifecycle
    # when #recv returns an error code.
    #
    def recvmsg message, flags = 0
      #LibXS.xs_recvmsg @socket, message.address, flags
      __recvmsg__(@socket, message.address, flags)
    end

    # Helper method to make a new #Message instance and convert its payload
    # to a string.
    #
    # +flags+ may be XS::NonBlocking.
    #
    # Returns 0 when the message was successfully dequeued.
    # Returns -1 under two conditions.
    # 1. The message could not be dequeued
    # 2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    # The application code is responsible for handling the +message+ object lifecycle
    # when #recv returns an error code.
    #
    def recv_string string, flags = 0
      message = @receiver_klass.new
      rc = recvmsg message, flags
      string.replace(message.copy_out_string) if Util.resultcode_ok?(rc)
      message.close
      rc
    end

    # Receive a multipart message as a list of strings.
    #
    # +flag+ may be XS::NonBlocking. Any other flag will be
    # removed.
    #
    def recv_strings list, flag = 0
      array = []
      rc = recvmsgs array, flag

      if Util.resultcode_ok?(rc)
        array.each do |message|
          list << message.copy_out_string
          message.close
        end
      end

      rc
    end

    # Receive a multipart message as an array of objects
    # (by default these are instances of Message).
    #
    # +flag+ may be XS::NonBlocking. Any other flag will be
    # removed.
    #
    def recvmsgs list, flag = 0
      flag = NonBlocking if dontwait?(flag)

      message = @receiver_klass.new
      rc = recvmsg message, flag

      if Util.resultcode_ok?(rc)
        list << message

        # check rc *first*; necessary because the call to #more_parts? can reset
        # the xs_errno to a weird value, so the xs_errno that was set on the
        # call to #recv gets lost
        while Util.resultcode_ok?(rc) && more_parts?
          message = @receiver_klass.new
          rc = recvmsg message, flag

          if Util.resultcode_ok?(rc)
            list << message
          else
            message.close
            list.each { |msg| msg.close }
            list.clear
          end
        end
      else
        message.close
      end

      rc
    end

    # Should only be used for XREQ, XREP, DEALER and ROUTER type sockets. Takes
    # a +list+ for receiving the message body parts and a +routing_envelope+
    # for receiving the message parts comprising the 0mq routing information.
    #
    def recv_multipart list, routing_envelope, flag = 0
      parts = []
      rc = recvmsgs parts, flag

      if Util.resultcode_ok?(rc)
        routing = true
        parts.each do |part|
          if routing
            routing_envelope << part
            routing = part.size > 0
          else
            list << part
          end
        end
      end

      rc
    end


    private

    def __getsockopt__ name, array
      # a small optimization so we only have to determine the option
      # type a single time; gives approx 5% speedup to do it this way.
      option_type = @option_lookup[name]

      value, length = sockopt_buffers option_type

      rc = LibXS.xs_getsockopt @socket, name, value, length

      if Util.resultcode_ok?(rc)
        array[0] = if 1 == option_type
          value.read_long_long
        elsif 0 == option_type
          value.read_int
        elsif 2 == option_type
          value.read_string(length.read_int)
        end
      end

      rc
    end

    # Calls to XS.getsockopt require us to pass in some pointers. We can cache and save those buffers
    # for subsequent calls. This is a big perf win for calling RCVMORE which happens quite often.
    # Cannot save the buffer for the IDENTITY.
    def sockopt_buffers option_type
      if 1 == option_type
        # int64_t or uint64_t
        unless @longlong_cache
          length = FFI::MemoryPointer.new :size_t
          length.write_int 8
          @longlong_cache = [FFI::MemoryPointer.new(:int64), length]
        end

        @longlong_cache

      elsif 0 == option_type
        # int, Crossroads assumes int is 4-bytes
        unless @int_cache
          length = FFI::MemoryPointer.new :size_t
          length.write_int 4
          @int_cache = [FFI::MemoryPointer.new(:int32), length]
        end

        @int_cache

      elsif 2 == option_type
        length = FFI::MemoryPointer.new :size_t
        # could be a string of up to 255 bytes
        length.write_int 255
        [FFI::MemoryPointer.new(255), length]

      else
        # uh oh, someone passed in an unknown option; use a slop buffer
        unless @int_cache
          length = FFI::MemoryPointer.new :size_t
          length.write_int 4
          @int_cache = [FFI::MemoryPointer.new(:int32), length]
        end

        @int_cache
      end
    end

    def populate_option_lookup
      # integer options
      [EVENTS, LINGER, RECONNECT_IVL, FD, TYPE, BACKLOG].each { |option| @option_lookup[option] = 0 }

      # long long options
      [RCVMORE, AFFINITY].each { |option| @option_lookup[option] = 1 }

      # string options
      [SUBSCRIBE, UNSUBSCRIBE].each { |option| @option_lookup[option] = 2 }
    end

    def release_cache
      @longlong_cache = nil
      @int_cache = nil
    end

    def dontwait?(flags)
      (NonBlocking & flags) == NonBlocking
    end
    alias :noblock? :dontwait?
  end # module CommonSocketBehavior


  module IdentitySupport

    # Convenience method for getting the value of the socket IDENTITY.
    #
    def identity
      array = []
      getsockopt IDENTITY, array
      array.at(0)
    end

    # Convenience method for setting the value of the socket IDENTITY.
    #
    def identity=(value)
      setsockopt IDENTITY, value.to_s
    end


    private

    def populate_option_lookup
      super()

      # string options
      [IDENTITY].each { |option| @option_lookup[option] = 2 }
    end

  end # module IdentitySupport

  class Socket
    include CommonSocketBehavior
    include IdentitySupport

    # Get the options set on this socket.
    #
    # +name+ determines the socket option to request
    # +array+ should be an empty array; a result of the proper type
    # (numeric, string, boolean) will be inserted into
    # the first position.
    #
    # Valid +option_name+ values:
    #  XS::RCVMORE - true or false
    #  XS::HWM - integer
    #  XS::SWAP - integer
    #  XS::AFFINITY - bitmap in an integer
    #  XS::IDENTITY - string
    #  XS::RATE - integer
    #  XS::RECOVERY_IVL - integer
    #  XS::SNDBUF - integer
    #  XS::RCVBUF - integer
    #  XS::FD     - fd in an integer
    #  XS::EVENTS - bitmap integer
    #  XS::LINGER - integer measured in milliseconds
    #  XS::RECONNECT_IVL - integer measured in milliseconds
    #  XS::BACKLOG - integer
    #  XS::RECOVER_IVL_MSEC - integer measured in milliseconds
    #
    # Returns 0 when the operation completed successfully.
    # Returns -1 when this operation failed.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    #  # retrieve high water mark
    #  array = []
    #  rc = socket.getsockopt(XS::HWM, array)
    #  hwm = array.first if XS::Util.resultcode_ok?(rc)
    #
    def getsockopt name, array
      rc = __getsockopt__ name, array

      if Util.resultcode_ok?(rc) && (RCVMORE == name)
        # convert to boolean
        array[0] = 1 == array[0]
      end

      rc
    end


    private

    def __sendmsg__(socket, address, flags)
      LibXS.xs_sendmsg(socket, address, flags)
    end

    def __recvmsg__(socket, address, flags)
      LibXS.xs_recvmsg(socket, address, flags)
    end

    def int_option? name
      super(name) ||
      RECONNECT_IVL_MAX == name ||
      RCVHWM            == name ||
      SNDHWM            == name ||
      RATE              == name ||
      RECOVERY_IVL      == name ||
      SNDBUF            == name ||
      RCVBUF            == name
    end

    def populate_option_lookup
      super()

      # integer options
      [RECONNECT_IVL_MAX, RCVHWM, SNDHWM, RATE, RECOVERY_IVL, SNDBUF, RCVBUF].each { |option| @option_lookup[option] = 0 }
    end

    # these finalizer-related methods cannot live in the CommonSocketBehavior
    # module; they *must* be in the class definition directly

    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@socket))
    end

    def remove_finalizer
      ObjectSpace.undefine_finalizer self
    end

    def self.close socket
      Proc.new { LibXS.xs_close socket }
    end
  end

end # module XS