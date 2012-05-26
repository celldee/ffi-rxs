# encoding: utf-8

module XS
  # Set up all of the constants
  
  # Context options
  MAX_SOCKETS = 1
  IO_THREADS = 2
  
  # Socket types
  PAIR = 0
  PUB = 1
  SUB = 2
  REQ = 3
  REP = 4
  XREQ = 5
  XREP = 6
  PULL = 7
  PUSH = 8
  XPUB = 9
  XSUB = 10
  SURVEYOR = 11
  RESPONDENT = 12
  XSURVEYOR = 13
  XRESPONDENT = 14
  
  DEALER = XREQ
  ROUTER = XREP

  SocketTypeNameMap = {
    PAIR => "PAIR",
    PUB => "PUB",
    SUB => "SUB",
    REQ => "REQ",
    REP => "REP",
    PULL => "PULL",
    PUSH => "PUSH",
    XREQ => "XREQ",
    XREP => "XREP",
    ROUTER => "ROUTER",
    DEALER => "DEALER",
    XPUB => "XPUB",
    XSUB => "XSUB"
  }

  # Socket options
  AFFINITY = 4
  IDENTITY = 5
  SUBSCRIBE = 6
  UNSUBSCRIBE = 7
  RATE = 8
  RECOVERY_IVL = 9
  SNDBUF = 11
  RCVBUF = 12
  RCVMORE = 13
  FD = 14
  EVENTS = 15
  TYPE = 16
  LINGER = 17
  RECONNECT_IVL = 18
  BACKLOG = 19
  RECONNECT_IVL_MAX = 21
  MAXMSGSIZE = 22
  SNDHWM = 23
  RCVHWM = 24
  MULTICAST_HOPS = 25
  RCVTIMEO = 27
  SNDTIMEO = 28
  IPV4ONLY = 31
  KEEPALIVE = 32
  PROTOCOL = 33
  SURVEY_TIMEOUT = 34
  
  # Message options
  MORE = 1

  # Send/recv options
  DONTWAIT = 1
  SNDMORE = 2
  NonBlocking = DONTWAIT

  # I/O multiplexing
  POLLIN = 1
  POLLOUT = 2
  POLLERR = 4

  # Socket errors
  EAGAIN = Errno::EAGAIN::Errno
  EFAULT = Errno::EFAULT::Errno
  EINVAL = Errno::EINVAL::Errno
  EMFILE = Errno::EMFILE::Errno
  ENOMEM = Errno::ENOMEM::Errno
  ENODEV = Errno::ENODEV::Errno
  
  # XS errors
  HAUSNUMERO     = 156384712
  EMTHREAD       = (HAUSNUMERO + 50)
  EFSM           = (HAUSNUMERO + 51)
  ENOCOMPATPROTO = (HAUSNUMERO + 52)
  ETERM          = (HAUSNUMERO + 53)

  # Rescue unknown constants and use the Crossroads defined values.
  # Usually only happens on Windows although some do not resolve on
  # OSX either _ENOTSUP_
  ENOTSUP         = Errno::ENOTSUP::Errno rescue (HAUSNUMERO + 1)
  EPROTONOSUPPORT = Errno::EPROTONOSUPPORT::Errno rescue (HAUSNUMERO + 2)
  ENOBUFS         = Errno::ENOBUFS::Errno rescue (HAUSNUMERO + 3)
  ENETDOWN        = Errno::ENETDOWN::Errno rescue (HAUSNUMERO + 4)
  EADDRINUSE      = Errno::EADDRINUSE::Errno rescue (HAUSNUMERO + 5)
  EADDRNOTAVAIL   = Errno::EADDRNOTAVAIL::Errno rescue (HAUSNUMERO + 6)
  ECONNREFUSED    = Errno::ECONNREFUSED::Errno rescue (HAUSNUMERO + 7)
  EINPROGRESS     = Errno::EINPROGRESS::Errno rescue (HAUSNUMERO + 8)
  ENOTSOCK        = Errno::ENOTSOCK::Errno rescue (HAUSNUMERO + 9)
  EINTR           = Errno::EINTR::Errno rescue (HAUSNUMERO + 10)
end # module XS
