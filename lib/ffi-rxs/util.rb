# encoding: utf-8

module XS

  # These methods don't belong to any specific class. They get included
  # in the #Context, #Socket and #Poller classes.
  #
  module Util

    # @return true when +rc+ is greater than or equal to 0
    # @return false otherwise
    #
    # We use the >= test because xs_poll() returns the number of sockets
    # that had a read or write event triggered. So, a >= 0 result means
    # it succeeded.
    #
    def self.resultcode_ok? rc
      rc >= 0
    end

    # @return errno as set by the libxs library.
    #
    def self.errno
      LibXS.xs_errno
    end

    # @return string corresponding to the currently set #errno. These
    # error strings are defined by libxs.
    #
    def self.error_string
      LibXS.xs_strerror(errno).read_string
    end

    # @return array of the form [major, minor, patch] to represent the
    # version of libxs
    #
    # Class method! Invoke as:  XS::Util.version
    #
    def self.version
      major = FFI::MemoryPointer.new :int
      minor = FFI::MemoryPointer.new :int
      patch = FFI::MemoryPointer.new :int
      LibXS.xs_version major, minor, patch
      [major.read_int, minor.read_int, patch.read_int]
    end

    # Attempts to bind to a random tcp port on +host+ up to +max_tries+
    # times. Returns the port number upon success or nil upon failure.
    #
    def self.bind_to_random_tcp_port host = '127.0.0.1', max_tries = 500
      tries = 0
      rc = -1

      while !resultcode_ok?(rc) && tries < max_tries
        tries += 1
        random = random_port
        rc = socket.bind "tcp://#{host}:#{random}"
      end

      resultcode_ok?(rc) ? random : nil
    end


    private

    # generate a random port between 10_000 and 65534
    def self.random_port
      rand(55534) + 10_000
    end

    # Called by most library methods to verify there were no errors during
    # operation. If any are found, raise the appropriate #XSError.
    #
    # @return true when no error is found which is behavior used internally
    # by #send and #recv.
    #
    def error_check source, result_code
      if -1 == result_code
        raise_error source, result_code
      end

      # used by Socket::send/recv, ignored by others
      true
    end

    def raise_error source, result_code
      if 'xs_init' == source || 'xs_socket' == source
        raise ContextError.new source, result_code, XS::Util.errno, XS::Util.error_string

      elsif ['xs_msg_init', 'xs_msg_init_data', 'xs_msg_copy', 'xs_msg_move'].include?(source)
        raise MessageError.new source, result_code, XS::Util.errno, XS::Util.error_string

      else
        puts "else"
        raise XSError.new source, result_code, -1,
        "Source [#{source}] does not match any xs_* strings, rc [#{result_code}], errno [#{XS::Util.errno}], error_string [#{XS::Util.error_string}]"
      end
    end

    def eagain?
      EAGAIN == XS::Util.errno
    end

  end # module Util

end # module XS
