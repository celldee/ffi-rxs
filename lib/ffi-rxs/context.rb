# encoding: utf-8

module XS

  # All sockets exist within a context and a context is passed to the
  # Socket constructor when allocating new sockets.
  #
  # Also, Sockets should *only* be accessed from the thread where they
  # were first created. Do *not* pass sockets between threads; pass
  # in the context and allocate a new socket per thread. If you must
  # use threads, then make sure to execute a full memory barrier (e.g.
  # mutex) as you pass a socket from one thread to the next.
  #
  # To connect sockets between contexts, use +inproc+ or +ipc+
  # transport and set up a Crossroads socket between them. This is also the
  # recommended technique for allowing sockets to communicate between
  # threads.
  #
  # @example Create context and socket
  #   context = XS::Context.create
  #   if context
  #     socket = context.socket(XS::REQ)
  #     if socket
  #       ...
  #     else
  #       STDERR.puts "Socket allocation failed"
  #     end
  #   else
  #     STDERR.puts "Context allocation failed"
  #   end
  class Context
    include XS::Util

    attr_reader :context, :pointer

    # Factory method to instantiate contexts
    def self.create
      new() rescue nil
    end
    
    # Initialize context object
    def initialize
      @sockets = []
      @context = LibXS.xs_init()
      @pointer = @context
      error_check 'xs_init', (@context.nil? || @context.null?) ? -1 : 0

      define_finalizer
    end
    
    # Sets options on a context.
    #
    # It is recommended to use the default for +io_threads+
    # (which is 1) since most programs will not saturate I/O. 
    #
    # The rule of thumb is to make io_threads equal to the number 
    # of gigabits per second that the application will produce.
    #
    # The io_threads number specifies the size of the thread pool
    # allocated by Crossroads for processing incoming/outgoing messages.
    #
    # The +max_sockets+ number specifies the number of concurrent
    # sockets that can be used in the context. The default is 512.
    #
    # Context options take effect only if set with **setctxopt()** prior to
    # creating the first socket in a given context with **socket()**.
    #
    # @param [Constant] name
    #   One of @XS::IO_THREADS@ or @XS::MAX_SOCKETS@.
    # @param [Integer] value  
    #  
    # @return 0 when the operation completed successfully.
    # @return -1 when this operation fails.
    #
    # @example Set io_threads context option
    #   rc = context.setctxopt(XS::IO_THREADS, 10)
    #   unless XS::Util.resultcode_ok?(rc)
    #     raise XS::ContextError.new('xs_setctxopt', rc, XS::Util.errno, XS::Util.error_string)
    #   end
    def setctxopt name, value
      length = 4
      pointer = LibC.malloc length
      pointer.write_int value

      rc = LibXS.xs_setctxopt @context, name, pointer, length
      LibC.free(pointer) unless pointer.nil? || pointer.null?
      rc
    end

    # Releases the context and any remaining data associated
    # with past sockets. This will close any sockets that remain
    # open; further calls to those sockets will return -1 to indicate
    # the operation failed.
    #
    # @return 0 for success
    # @return -1 for failure
    def terminate
      unless @context.nil? || @context.null?
        remove_finalizer
        rc = LibXS.xs_term @context
        @context = nil
        @sockets = nil
        rc
      else
        0
      end
    end

    # Allocates a socket for context
    #
    # @param [Constant] type
    #   One of @XS::REQ@, @XS::REP@, @XS::PUB@, @XS::SUB@, @XS::PAIR@,
    #          @XS::PULL@, @XS::PUSH@, @XS::DEALER@, or @XS::ROUTER@
    #
    # @return [Socket] when the allocation succeeds
    # @return nil when call fails
    def socket type
      sock = nil
      begin
        sock = Socket.new @context, type
      rescue ContextError => e
        sock = nil
      end
      
      sock
    end


    private

    # Deletes native resources after object has been destroyed
    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@context))
    end
    
    # Removes all finalizers for object
    def remove_finalizer
      ObjectSpace.undefine_finalizer self
    end

    # Closes the context
    def self.close context
      Proc.new { LibXS.xs_term context unless context.null? }
    end
  end

end # module XS
