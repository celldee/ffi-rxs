# Execute 'rake spec' from the main directory to run all specs.

require File.expand_path(
File.join(File.dirname(__FILE__), %w[.. lib ffi-rxs]))

Thread.abort_on_exception = true

module APIHelper
  def stub_libxs
    @err_str_mock = mock("error string")

    LibXS.stub!(
    :xs_init => 0,
    :xs_errno => 0,
    :xs_sterror => @err_str_mock
    )
  end

  # generate a random port between 10_000 and 65534
  def random_port
    rand(55534) + 10_000
  end

  def bind_to_random_tcp_port socket, max_tries = 500
    tries = 0
    rc = -1

    while !XS::Util.resultcode_ok?(rc) && tries < max_tries
      tries += 1
      random = random_port
      rc = socket.bind(local_transport_string(random))
    end

    random
  end

  def connect_to_random_tcp_port socket, max_tries = 500
    tries = 0
    rc = -1

    while !XS::Util.resultcode_ok?(rc) && tries < max_tries
      tries += 1
      random = random_port
      rc = socket.connect(local_transport_string(random))
    end

    random
  end
  
  def local_transport_string(port)
    "tcp://127.0.0.1:#{port}"
  end

  def assert_ok(rc)
    raise "Failed with rc [#{rc}] and errno [#{XS::Util.errno}], msg [#{XS::Util.error_string}]! #{caller(0)}" unless rc >= 0
  end
end
