# Safe way to intercept IO stream
# where just replacing STDOUT doesn't work:
# http://rubyforge.org/tracker/index.php?func=detail&aid=5217&group_id=426&atid=1698
#
module IoInterceptor
  def intercept
    begin
      @intercept = true
      @intercepted = ""
      yield
    ensure
      @intercept = false
    end
    @intercepted
  end

  def supress
    begin
      @supress = true
      yield
    ensure
      @supress = false
    end
  end

  def write(str)
    if @supress || @intercept
      @intercepted << str.to_s unless @supress 
      str.size
    else
      super
    end
  end
end

if $PROGRAM_NAME == __FILE__
  require 'spec'

  describe IoInterceptor do
    before do
      STDOUT.extend(IoInterceptor)
    end

    it "intercepts output to stream when the stream is extended with it" do
      STDOUT.intercept { STDOUT.puts("42") }.should == "42\n"
      STDOUT.intercept { STDOUT.puts("24") }.should == "24\n"
    end

    it "intercepted IO#write still returns the number of bytes written" do
      STDOUT.intercept { STDOUT.write("42").should == 2 }
    end

    it "intercepted IO#write argument is converted using to_s" do
      obj = "42"
      def obj.to_s
        "custom to_s"
      end
      
      STDOUT.intercept { STDOUT.puts(obj) }.should == "#{ obj.to_s }\n"
    end
  end

  exit ::Spec::Runner::CommandLine.run
end