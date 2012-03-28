# encoding: utf-8

module XS


  # Recommended to use the default for +io_threads+
  # since most programs will not saturate I/O. 
  #
  # The rule of thumb is to make +io_threads+ equal to the number 
  # gigabits per second that the application will produce.
  #
  # The +io_threads+ number specifies the size of the thread pool
  # allocated by 0mq for processing incoming/outgoing messages.
  #
  # Returns a context object when allocation succeeds. It's necessary
  # for passing to the
  # #Socket constructor when allocating new sockets. All sockets
  # live within a context.
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
  #  context = XS::Context.create
  #  if context
  #    socket = context.socket(XS::REQ)
  #    if socket
  #      ...
  #    else
  #      STDERR.puts "Socket allocation failed"
  #    end
  #  else
  #    STDERR.puts "Context allocation failed"
  #  end
  #
  #
  class Context
    include XS::Util

    attr_reader :context, :pointer

    def self.create
      new() rescue nil
    end
    
    # Use the factory method Context#create to make contexts.
    #
    def initialize
      @sockets = []
      @context = LibXS.xs_init()
      @pointer = @context
      error_check 'xs_init', (@context.nil? || @context.null?) ? -1 : 0

      define_finalizer
    end
    
    # Set options on this context.
    #
    # Context options take effect only if set with setctxopt() prior to
    # creating the first socket in a given context with socket().
    #
    # Valid +name+ values that take a numeric +value+ are:
    #  XS::IO_THREADS
    #  XS::MAX_SOCKETS
    #
    # Returns 0 when the operation completed successfully.
    # Returns -1 when this operation failed.
    #
    # With a -1 return code, the user must check XS.errno to determine the
    # cause.
    #
    #  rc = context.setctxopt(XS::IO_THREADS, 10)
    #  XS::Util.resultcode_ok?(rc) ? puts("succeeded") : puts("failed")
    #
    def setctxopt name, value, length = nil
      length = 4
      pointer = LibC.malloc length
      pointer.write_int value

      rc = LibXS.xs_setctxopt @context, name, pointer, length
      LibC.free(pointer) unless pointer.nil? || pointer.null?
      rc
    end

    # Call to release the context and any remaining data associated
    # with past sockets. This will close any sockets that remain
    # open; further calls to those sockets will return -1 to indicate
    # the operation failed.
    #
    # Returns 0 for success, -1 for failure.
    #
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

    # Short-cut to allocate a socket for a specific context.
    #
    # Takes several +type+ values:
    #   #XS::REQ
    #   #XS::REP
    #   #XS::PUB
    #   #XS::SUB
    #   #XS::PAIR
    #   #XS::PULL
    #   #XS::PUSH
    #   #XS::DEALER
    #   #XS::ROUTER
    #
    # Returns a #XS::Socket when the allocation succeeds, nil
    # if it fails.
    #
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

    def define_finalizer
      ObjectSpace.define_finalizer(self, self.class.close(@context))
    end

    def remove_finalizer
      ObjectSpace.undefine_finalizer self
    end

    def self.close context
      Proc.new { LibXS.xs_term context unless context.null? }
    end
  end

end # module XS
