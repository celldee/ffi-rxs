# encoding: utf-8

module XS

  # Wraps the libxs library and attaches to the API functions
  #
  module LibXS
    extend FFI::Library

    begin
      # bias the library discovery to a path inside the gem first, then
      # to the usual system paths
      inside_gem = File.join(File.dirname(__FILE__), '..', '..', 'ext')
      XS_LIB_PATHS = [
      inside_gem, '/usr/local/lib', '/opt/local/lib', '/usr/local/homebrew/lib', '/usr/lib64'
      ].map{|path| "#{path}/libxs.#{FFI::Platform::LIBSUFFIX}"}
      ffi_lib(XS_LIB_PATHS + %w{libxs})
    rescue LoadError
      STDERR.puts "Unable to load this gem. The libxs library (or DLL) could not be found."
      STDERR.puts "If this is a Windows platform, make sure libxs.dll is on the PATH."
      STDERR.puts "For non-Windows platforms, make sure libxs is located in this search path:"
      STDERR.puts XS_LIB_PATHS.inspect
      exit 255
    end

    # Size_t not working properly on Windows
    find_type(:size_t) rescue typedef(:ulong, :size_t)

    # Context and misc api
    #
    # @blocking = true is a hint to FFI that the following (and only the following)
    # function may block, therefore it should release the GIL before calling it.
    # This can aid in situations where the function call will/may block and another
    # thread within the lib may try to call back into the ruby runtime. Failure to
    # release the GIL will result in a hang; the hint *may* allow things to run
    # smoothly for Ruby runtimes hampered by a GIL.
    #
    # This is really only honored by the MRI implementation but it *is* necessary
    # otherwise the runtime hangs (and requires a kill -9 to terminate)
    #
    @blocking = true
    attach_function :xs_errno, [], :int
    @blocking = true
    attach_function :xs_init, [], :pointer
    @blocking = true
    attach_function :xs_setctxopt, [:pointer, :int, :pointer, :int], :int
    @blocking = true
    attach_function :xs_shutdown, [:pointer, :int], :int
    @blocking = true
    attach_function :xs_socket, [:pointer, :int], :pointer
    @blocking = true
    attach_function :xs_strerror, [:int], :pointer
    @blocking = true
    attach_function :xs_term, [:pointer], :int
    @blocking = true
    attach_function :xs_version, [:pointer, :pointer, :pointer], :void

    def self.version
      if @version.nil?
        major = FFI::MemoryPointer.new :int
        minor = FFI::MemoryPointer.new :int
        patch = FFI::MemoryPointer.new :int
        LibXS.xs_version major, minor, patch
        @version = {:major => major.read_int, :minor => minor.read_int, :patch => patch.read_int}
      end

      @version
    end

    # Message api
    @blocking = true
    attach_function :xs_msg_close, [:pointer], :int
    @blocking = true
    attach_function :xs_msg_copy, [:pointer, :pointer], :int
    @blocking = true
    attach_function :xs_msg_data, [:pointer], :pointer
    @blocking = true
    attach_function :xs_msg_init, [:pointer], :int
    @blocking = true
    attach_function :xs_msg_init_size, [:pointer, :size_t], :int
    @blocking = true
    attach_function :xs_msg_init_data, [:pointer, :pointer, :size_t, :pointer, :pointer], :int
    @blocking = true
    attach_function :xs_msg_move, [:pointer, :pointer], :int
    @blocking = true
    attach_function :xs_msg_size, [:pointer], :size_t
    
    # Used for casting pointers back to the struct
    #
    class Msg < FFI::Struct
      layout :content,  :pointer,
      :flags,    :uint8,
      :vsm_size, :uint8,
      :vsm_data, [:uint8, 30]
    end # class Msg

    # Socket api
    @blocking = true
    attach_function :xs_bind, [:pointer, :string], :int
    @blocking = true
    attach_function :xs_connect, [:pointer, :string], :int
    @blocking = true
    attach_function :xs_close, [:pointer], :int
    @blocking = true
    attach_function :xs_getsockopt, [:pointer, :int, :pointer, :pointer], :int
    @blocking = true
    attach_function :xs_recvmsg, [:pointer, :pointer, :int], :int
    @blocking = true
    attach_function :xs_recv, [:pointer, :pointer, :size_t, :int], :int
    @blocking = true
    attach_function :xs_sendmsg, [:pointer, :pointer, :int], :int
    @blocking = true
    attach_function :xs_send, [:pointer, :pointer, :size_t, :int], :int
    @blocking = true
    attach_function :xs_setsockopt, [:pointer, :int, :pointer, :int], :int

    # Poll api
    @blocking = true
    attach_function :xs_poll, [:pointer, :int, :long], :int

    module PollItemLayout
      def self.included(base)
        base.class_eval do
          layout :socket,  :pointer,
          :fd,    :int,
          :events, :short,
          :revents, :short
        end
      end
    end # module PollItemLayout

    class PollItem < FFI::Struct
      include PollItemLayout

      def socket() self[:socket]; end
      
      def fd() self[:fd]; end

      def readable?
        (self[:revents] & XS::POLLIN) > 0
      end

      def writable?
        (self[:revents] & XS::POLLOUT) > 0
      end

      def both_accessible?
        readable? && writable?
      end

      def inspect
        "socket [#{socket}], fd [#{fd}], events [#{self[:events]}], revents [#{self[:revents]}]"
      end

      def to_s; inspect; end
    end # class PollItem

  end

end # module XS
