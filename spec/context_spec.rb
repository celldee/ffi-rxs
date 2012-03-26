$: << "." # added for ruby 1.9.2 compatibilty; it doesn't include the current directory on the load path anymore

require File.join(File.dirname(__FILE__), %w[spec_helper])

module XS


  describe Context do

    context "when initializing with factory method #create" do
      include APIHelper

      it "should return nil for negative io threads" do
        LibXS.stub(:xs_init => nil)
        Context.create(-1).should be_nil
      end
      
      it "should default to requesting 1 i/o thread when no argument is passed" do
        ctx = mock('ctx')
        ctx.stub!(:null? => false)
        LibXS.should_receive(:xs_init).with(1).and_return(ctx)
        
        Context.create
      end

      it "should set the :pointer accessor to non-nil" do
        ctx = Context.create
        ctx.pointer.should_not be_nil
      end

      it "should set the :context accessor to non-nil" do
        ctx = Context.create
        ctx.context.should_not be_nil
      end

      it "should set the :pointer and :context accessors to the same value" do
        ctx = Context.create
        ctx.pointer.should == ctx.context
      end
      
      it "should define a finalizer on this object" do
        ObjectSpace.should_receive(:define_finalizer)
        ctx = Context.create
      end
    end # context initializing


    context "when initializing with #new" do
      include APIHelper

      it "should raise an error for negative io threads" do
        LibXS.stub(:xs_init => nil)
        lambda { Context.new(-1) }.should raise_exception(XS::ContextError)
      end
      
      it "should default to requesting 1 i/o thread when no argument is passed" do
        ctx = mock('ctx')
        ctx.stub!(:null? => false)
        LibXS.should_receive(:xs_init).with(1).and_return(ctx)
        
        Context.new
      end

      it "should set the :pointer accessor to non-nil" do
        ctx = Context.new
        ctx.pointer.should_not be_nil
      end

      it "should set the :context accessor to non-nil" do
        ctx = Context.new
        ctx.context.should_not be_nil
      end

      it "should set the :pointer and :context accessors to the same value" do
        ctx = Context.new
        ctx.pointer.should == ctx.context
      end
      
      it "should define a finalizer on this object" do
        ObjectSpace.should_receive(:define_finalizer)
        ctx = Context.new 1
      end
    end # context initializing


    context "when terminating" do
      it "should call xs_term to terminate the library's context" do
        ctx = Context.new # can't use a shared context here because we are terminating it!
        LibXS.should_receive(:xs_term).with(ctx.pointer).and_return(0)
        ctx.terminate
      end
    end # context terminate


    context "when allocating a socket" do
      it "should return nil when allocation fails" do
        ctx = Context.new
        LibXS.stub!(:xs_socket => nil)
        ctx.socket(XS::REQ).should be_nil
      end
    end # context socket

  end # describe Context


end # module XS
