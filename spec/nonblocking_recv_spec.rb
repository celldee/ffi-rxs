
require File.join(File.dirname(__FILE__), %w[spec_helper])

module XS


  describe Socket do
    before(:all) do
      @ctx = Context.new
    end

    after(:all) do
      @ctx.terminate
    end


    shared_examples_for "any socket" do

      it "returns -1 when there are no messages to read" do
        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        Util.resultcode_ok?(rc).should be_false
      end

      it "gets EAGAIN when there are no messages to read" do
        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        XS::Util.errno.should == XS::EAGAIN
      end

      it "returns the given array unmodified when there are no messages to read" do
        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        array.size.should be_zero
      end

    end

    shared_examples_for "sockets without exposed envelopes" do

      it "read the single message and returns a successful result code" do
        rc = @sender.send_string('test')
        Util.resultcode_ok?(rc).should be_true
        sleep 0.1 # give it time to deliver to the receiver

        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        Util.resultcode_ok?(rc).should be_true
        array.size.should == 1
      end

      it "read all message parts transmitted and returns a successful result code" do
        strings = Array.new(10, 'test')
        rc = @sender.send_strings(strings)
        Util.resultcode_ok?(rc).should be_true
        sleep 0.1 # give it time to deliver to the sub socket

        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        Util.resultcode_ok?(rc).should be_true
        array.size.should == 10
      end

    end

    shared_examples_for "sockets with exposed envelopes" do

      it "read the single message and returns a successful result code" do
        rc = @sender.send_string('test')
        Util.resultcode_ok?(rc).should be_true
        sleep 0.1 # give it time to deliver to the receiver

        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        Util.resultcode_ok?(rc).should be_true
        array.size.should == 1 + 1 # extra 1 for envelope
      end

      it "read all message parts transmitted and returns a successful result code" do
        strings = Array.new(10, 'test')
        rc = @sender.send_strings(strings)
        Util.resultcode_ok?(rc).should be_true
        sleep 0.1 # give it time to deliver to the sub socket

        array = []
        rc = @receiver.recvmsgs(array, XS::NonBlocking)
        Util.resultcode_ok?(rc).should be_true
        array.size.should == 10 + 1 # add 1 for the envelope
      end

    end

    context "PUB" do

      describe "non-blocking #recvmsgs where sender binds & receiver connects" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::SUB
          port = connect_to_random_tcp_port(@receiver)
          assert_ok(@receiver.setsockopt(XS::SUBSCRIBE, ''))
          @sender = @ctx.socket XS::PUB
          assert_ok(@sender.bind("tcp://127.0.0.1:#{port}"))
          sleep 0.3
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets without exposed envelopes"

      end # describe 'non-blocking recvmsgs'

    end # Pub

    context "REQ" do

      describe "non-blocking #recvmsgs where sender connects & receiver binds" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::REP
          port = bind_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::REQ
          assert_ok(@sender.connect("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets without exposed envelopes"

      end # describe 'non-blocking recvmsgs'

      describe "non-blocking #recvmsgs where sender binds & receiver connects" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::REP
          port = connect_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::REQ
          assert_ok(@sender.bind("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets without exposed envelopes"

      end # describe 'non-blocking recvmsgs'

    end # REQ


    context "PUSH" do

      describe "non-blocking #recvmsgs where sender connects & receiver binds" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::PULL
          port = bind_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::PUSH
          assert_ok(@sender.connect("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets without exposed envelopes"

      end # describe 'non-blocking recvmsgs'

      describe "non-blocking #recvmsgs where sender binds & receiver connects" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::PULL
          port = connect_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::PUSH
          assert_ok(@sender.bind("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets without exposed envelopes"

      end # describe 'non-blocking recvmsgs'

    end # PUSH


    context "DEALER" do

      describe "non-blocking #recvmsgs where sender connects & receiver binds" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::ROUTER
          port = bind_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::DEALER
          assert_ok(@sender.connect("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets with exposed envelopes"

      end # describe 'non-blocking recvmsgs'

      describe "non-blocking #recvmsgs where sender binds & receiver connects" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::ROUTER
          port = connect_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::DEALER
          assert_ok(@sender.bind("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets with exposed envelopes"

      end # describe 'non-blocking recvmsgs'

    end # DEALER


    context "XREQ" do

      describe "non-blocking #recvmsgs where sender connects & receiver binds" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::XREP
          port = bind_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::XREQ
          assert_ok(@sender.connect("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets with exposed envelopes"

      end # describe 'non-blocking recvmsgs'

      describe "non-blocking #recvmsgs where sender binds & receiver connects" do
        include APIHelper

        before(:each) do
          @receiver = @ctx.socket XS::XREP
          port = connect_to_random_tcp_port(@receiver)
          @sender = @ctx.socket XS::XREQ
          assert_ok(@sender.bind("tcp://127.0.0.1:#{port}"))
          sleep 0.1
        end

        after(:each) do
          @receiver.close
          @sender.close
        end

        it_behaves_like "any socket"
        it_behaves_like "sockets with exposed envelopes"

      end # describe 'non-blocking recvmsgs'

    end # XREQ

  end # describe Socket


end # module XS
