# encoding: utf-8

module XS

  module CommonSocketBehavior

    attr_reader :socket, :name

    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # By default, this class uses XS::Message for manual
    # memory management. For automatic garbage collection of received messages,
    # it is possible to override the :receiver_class to use XS::ManagedMessage.
    #
    # @example Socket creation
    #   sock = Socket.create(Context.create, XS::REQ, :receiver_class => XS::ManagedMessage)
    #
    # Advanced users may want to replace the receiver class with their
    # own custom class. The custom class must conform to the same public API
    # as XS::Message.
    #
    # 
    # @example
    #   if (socket = Socket.new(context.pointer, XS::REQ))
    #     ...
    #   else
    #     STDERR.puts "Socket creation failed"
    #   end
    #
    # @param pointer
    # @param [Constant] type
    #   One of @XS::REQ@, @XS::REP@, @XS::PUB@, @XS::SUB@, @XS::PAIR@,
    #          @XS::PULL@, @XS::PUSH@, @XS::XREQ@, @XS::REP@,
    #          @XS::DEALER@ or @XS::ROUTER@
    # @param [Hash] options
    #
    # @return [Socket] when successful
    # @return nil when unsuccessful
    def self.create context_ptr, type, opts = {:receiver_class => XS::Message}
      new(context_ptr, type, opts) rescue nil
    end

    # Allocates a socket of type +type+ for sending and receiving data.
    #
    # To avoid rescuing exceptions, use the factory method #create for
    # all socket creation.
    #
    # By default, this class uses XS::Message for manual
    # memory management. For automatic garbage collection of received messages,
    # it is possible to override the :receiver_class to use XS::ManagedMessage.
    #
    # @example Socket creation
    #   sock = Socket.new(Context.new, XS::REQ, :receiver_class => XS::ManagedMessage)
    #
    # Advanced users may want to replace the receiver class with their
    # own custom class. The custom class must conform to the same public API
    # as XS::Message.
    #
    # Creation of a new Socket object can raise an exception. This occurs when the
    # +context_ptr+ is null or when the allocation of the Crossroads socket within the
    # context fails.
    #
    # @example
    #   begin
    #     socket = Socket.new(context.pointer, XS::REQ)
    #   rescue ContextError => e
    #     # error handling
    #   end
    #
    # @param pointer
    # @param [Constant] type
    #   One of @XS::REQ@, @XS::REP@, @XS::PUB@, @XS::SUB@, @XS::PAIR@,
    #          @XS::PULL@, @XS::PUSH@, @XS::XREQ@, @XS::REP@,
    #          @XS::DEALER@ or @XS::ROUTER@
    # @param [Hash] options
    #
    # @return [Socket] when successful
    # @return nil when unsuccessful
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

    # Set the queue options on this socket
    #
    # @param [Constant] name numeric values
    #   One of @XS::AFFINITY@, @XS::RATE@, @XS::RECOVERY_IVL@,
    #          @XS::LINGER@, @XS::RECONNECT_IVL@, @XS::BACKLOG@,
    #          @XS::RECONNECT_IVL_MAX@, @XS::MAXMSGSIZE@, @XS::SNDHWM@,
    #          @XS::RCVHWM@, @XS::MULTICAST_HOPS@, @XS::RCVTIMEO@,
    #          @XS::SNDTIMEO@, @XS::IPV4ONLY@, @XS::KEEPALIVE@,
    #          @XS::SUBSCRIBE@, @XS::UNSUBSCRIBE@, @XS::IDENTITY@,
    #          @XS::SNDBUF@, @XS::RCVBUF@
    # @param [Constant] name string values
    #   One of @XS::IDENTITY@, @XS::SUBSCRIBE@ or @XS::UNSUBSCRIBE@
    # @param value
    #
    # @return 0 when the operation completed successfully
    # @return -1 when this operation fails
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    # @example
    #   rc = socket.setsockopt(XS::LINGER, 1_000)
    #   XS::Util.resultcode_ok?(rc) ? puts("succeeded") : puts("failed")
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
    # @example
    #   message_parts = []
    #   message = Message.new
    #   rc = socket.recvmsg(message)
    #   if XS::Util.resultcode_ok?(rc)
    #     message_parts << message
    #     while more_parts?
    #       message = Message.new
    #       rc = socket.recvmsg(message)
    #       message_parts.push(message) if resultcode_ok?(rc)
    #     end
    #   end
    #
    # @return true if more message parts
    # @return false if not
    def more_parts?
      rc = getsockopt XS::RCVMORE, @more_parts_array

      Util.resultcode_ok?(rc) ? @more_parts_array.at(0) : false
    end

    # Binds the socket to an +address+.
    #
    # @example
    #   socket.bind("tcp://127.0.0.1:5555")
    #
    # @param address
    def bind address
      LibXS.xs_bind @socket, address
    end

    # Connects the socket to an +address+.
    #
    # @example
    #   rc = socket.connect("tcp://127.0.0.1:5555")
    #
    # @param address
    #
    # @return 0 if successful
    # @return -1 if unsuccessful
    def connect address
      LibXS.xs_connect @socket, address
    end

    # Closes the socket. Any unprocessed messages in queue are sent or dropped
    # depending upon the value of the socket option XS::LINGER.
    #
    # @example
    #   rc = socket.close
    #   puts("Given socket was invalid!") unless 0 == rc
    #
    # @return 0 upon success *or* when the socket has already been closed
    # @return -1 when the operation fails. Check XS.errno for the error code
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
    # @param message
    # @param flag
    #   One of @0 (default) - blocking operation@, @XS::NonBlocking - non-blocking operation@,
    #          @XS::SNDMORE - this message is part of a multi-part message@
    #
    # @return 0 when the message was successfully enqueued
    # @return -1 under two conditions
    #   1. The message could not be enqueued
    #   2. When +flag+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    def sendmsg message, flag = 0
      __sendmsg__(@socket, message.address, flag)
    end

    # Helper method to make a new #Message instance out of the +string+ passed
    # in for transmission.
    #
    # @param message
    # @param flag
    #   One of @0 (default)@, @XS::NonBlocking@ and @XS::SNDMORE@
    #
    # @return 0 when the message was successfully enqueued
    # @return -1 under two conditions
    #   1. The message could not be enqueued
    #   2. When +flag+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    def send_string string, flag = 0
      message = Message.new string
      send_and_close message, flag
    end

    # Send a sequence of strings as a multipart message out of the +parts+
    # passed in for transmission. Every element of +parts+ should be
    # a String.
    #
    # @param [Array] parts
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking@
    #
    # @return 0 when the messages were successfully enqueued
    # @return -1 under two conditions
    #   1. A message could not be enqueued
    #   2. When +flag+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    def send_strings parts, flag = 0
      return -1 if !parts || parts.empty?
      flag = NonBlocking if dontwait?(flag)

      parts[0..-2].each do |part|
        rc = send_string part, (flag | XS::SNDMORE)
        return rc unless Util.resultcode_ok?(rc)
      end

      send_string parts[-1], flag
    end

    # Send a sequence of messages as a multipart message out of the +parts+
    # passed in for transmission. Every element of +parts+ should be
    # a Message (or subclass).
    #
    # @param [Array] parts
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking@
    #
    # @return 0 when the messages were successfully enqueued
    # @return -1 under two conditions
    #   1. A message could not be enqueued
    #   2. When +flag+ is set with XS::NonBlocking and the socket returned EAGAIN
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    def sendmsgs parts, flag = 0
      return -1 if !parts || parts.empty?
      flag = NonBlocking if dontwait?(flag)

      parts[0..-2].each do |part|
        rc = sendmsg part, (flag | XS::SNDMORE)
        return rc unless Util.resultcode_ok?(rc)
      end

      sendmsg parts[-1], flag
    end

    # Sends a message. This will automatically close the +message+ for both successful
    # and failed sends.
    #
    # @param message
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking
    #
    # @return 0 when the message was successfully enqueued
    # @return -1 under two conditions
    #   1. The message could not be enqueued
    #   2. When +flag+ is set with XS::NonBlocking and the socket returned EAGAIN.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    def send_and_close message, flag = 0
      rc = sendmsg message, flag
      message.close
      rc
    end

    # Dequeues a message from the underlying queue. By default, this is a blocking operation.
    #
    # @param message
    # @param flag
    #   One of @0 (default) - blocking operation@ and @XS::NonBlocking - non-blocking operation@
    #
    # @return 0 when the message was successfully dequeued
    # @return -1 under two conditions
    #   1. The message could not be dequeued
    #   2. When +flags+ is set with XS::NonBlocking and the socket returned EAGAIN
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    # The application code is responsible for handling the +message+ object lifecycle
    # when #recv returns an error code.
    def recvmsg message, flag = 0
      __recvmsg__(@socket, message.address, flag)
    end

    # Helper method to make a new #Message instance and convert its payload
    # to a string.
    #
    # @param string
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking@
    #
    # @return 0 when the message was successfully dequeued
    # @return -1 under two conditions
    #   1. The message could not be dequeued
    #   2. When +flag+ is set with XS::NonBlocking and the socket returned EAGAIN
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    # The application code is responsible for handling the +message+ object lifecycle
    # when #recv returns an error code.
    def recv_string string, flag = 0
      message = @receiver_klass.new
      rc = recvmsg message, flag
      string.replace(message.copy_out_string) if Util.resultcode_ok?(rc)
      message.close
      rc
    end

    # Receive a multipart message as a list of strings.
    #
    # @param [Array] list
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking@. Any other flag will be
    #   removed.
    #
    # @return 0 if successful
    # @return -1 if unsuccessful
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
    # @param [Array] list
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking@. Any other flag will be
    #   removed.
    #
    # @return 0 if successful
    # @return -1 if unsuccessful
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
    # @param [Array] list
    # @param routing_envelope
    # @param flag
    #   One of @0 (default)@ and @XS::NonBlocking@
    #
    # @return 0 if successful
    # @return -1 if unsuccessful
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

    # Gets socket option
    #
    # @param name
    # @param array
    #
    # @return option number
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

    # Calls to xs_getsockopt require us to pass in some pointers. We can cache and save those buffers
    # for subsequent calls. This is a big perf win for calling RCVMORE which happens quite often.
    # Cannot save the buffer for the IDENTITY.
    #
    # @param option_type
    # @return cached number or string
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

    # Populate socket option lookup array
    def populate_option_lookup
      # integer options
      [EVENTS, LINGER, RECONNECT_IVL, FD, TYPE, BACKLOG, KEEPALIVE, IPV4ONLY].each { |option| @option_lookup[option] = 0 }

      # long long options
      [RCVMORE, AFFINITY].each { |option| @option_lookup[option] = 1 }

      # string options
      [SUBSCRIBE, UNSUBSCRIBE].each { |option| @option_lookup[option] = 2 }
    end

    # Initialize caches
    def release_cache
      @longlong_cache = nil
      @int_cache = nil
    end

    # Convenience method to decide whether flag is DONTWAIT
    #
    # @param flag
    #
    # @return true if is DONTWAIT
    # @return false if not
    def dontwait?(flag)
      (NonBlocking & flag) == NonBlocking
    end
    alias :noblock? :dontwait?
  end # module CommonSocketBehavior


  module IdentitySupport

    # Convenience method for getting the value of the socket IDENTITY.
    #
    # @return identity
    def identity
      array = []
      getsockopt IDENTITY, array
      array.at(0)
    end

    # Convenience method for setting the value of the socket IDENTITY.
    #
    # @param value
    def identity=(value)
      setsockopt IDENTITY, value.to_s
    end


    private

    # Populate option lookup array
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
    # @param name
    #   One of @XS::RCVMORE@, @XS::SNDHWM@, @XS::AFFINITY@, @XS::IDENTITY@,
    #          @XS::RATE@, @XS::RECOVERY_IVL@, @XS::SNDBUF@,
    #          @XS::RCVBUF@, @XS::FD@, @XS::EVENTS@, @XS::LINGER@,
    #          @XS::RECONNECT_IVL@, @XS::BACKLOG@, XS::RECONNECT_IVL_MAX@,
    #          @XS::RCVTIMEO@, @XS::SNDTIMEO@, @XS::IPV4ONLY@, @XS::TYPE@,
    #          @XS::RCVHWM@, @XS::MAXMSGSIZE@, @XS::MULTICAST_HOPS@,
    #          @XS::KEEPALIVE@
    # @param array should be an empty array; a result of the proper type
    #   (numeric, string, boolean) will be inserted into
    #   the first position.
    #
    # @return 0 when the operation completed successfully
    # @return -1 when this operation failed
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    # @example Retrieve send high water mark
    #   array = []
    #   rc = socket.getsockopt(XS::SNDHWM, array)
    #   sndhwm = array.first if XS::Util.resultcode_ok?(rc)
    def getsockopt name, array
      rc = __getsockopt__ name, array

      if Util.resultcode_ok?(rc) && (RCVMORE == name)
        # convert to boolean
        array[0] = 1 == array[0]
      end

      rc
    end


    private

    # Queue message to send
    #
    # @param socket
    # @param address
    # @param flag
    def __sendmsg__(socket, address, flag)
      LibXS.xs_sendmsg(socket, address, flag)
    end

    # Receive message
    #
    # @param socket
    # @param address
    # @param flag
    def __recvmsg__(socket, address, flag)
      LibXS.xs_recvmsg(socket, address, flag)
    end

    # Populate socket option lookup array
    def populate_option_lookup
      super()

      # integer options
      [RECONNECT_IVL_MAX, RCVHWM, SNDHWM, RATE, RECOVERY_IVL, SNDBUF, RCVBUF].each { |option| @option_lookup[option] = 0 }
    end

    # these finalizer-related methods cannot live in the CommonSocketBehavior
    # module; they *must* be in the class definition directly
    #
    # Deletes native resources after object has been destroyed
    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@socket))
    end

    # Removes all finalizers for object
    def remove_finalizer
      ObjectSpace.undefine_finalizer self
    end

    # Closes the socket
    def self.close socket
      Proc.new { LibXS.xs_close socket }
    end
  end

end # module XS
