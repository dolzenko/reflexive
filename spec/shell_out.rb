# ## ShellOut
#
# Provides a convenient feature-rich way to "shell out" to external commands.
# Most useful features come from using `PTY` to execute the command. Not available
# on Windows, `Kernel#system` will be used instead.
#
# ## Features
#
# ### Interruption
#
# The external command can be easily interrupted and `Interrupt` exception
# will propagate to the calling program.
#
# For example while something like this can hang your terminal
#
#     loop { system("ls -R /") } # => lists directories indefinitely,
#                                # Ctrl-C only stops ls
#
# That won't be the case with ShellOut:
#
#     require "shell_out"
#     include ShellOut
#     loop { shell_out("ls -R /") } # => when Ctrl-C is pressed ls is terminated
#                                   # and Interrupt exception is propagated
#
# Yes it's possible to examine the `$CHILD_STATUS.exitstatus` variable but that's
# not nearly as robust and flexible as `PTY` solution. 
#
# ### TTY-like Output
#
# External command is running in pseudo TTY provided by `PTY` library on Unix,
# which means that commands like `ffmpeg`, `git` can report progress and
# **otherwise interact with user as usual**.
#
# ### Output Capturing
#
# Output of the command can be captured using `:out` option
#
#     io = StringIO.new
#     shell_out("echo 42", :out => io) # doesn't print anything
#     io.string.chomp # => "42"
#
# If `:out => :return` option is passed - the `shell_out` return the output
# of the command instead of exit status.
#
# ### :raise_exceptions, :verbose, :noop, and :dry_run Options
#
# * `:raise_exceptions => true` will raise `ShellOutException` for any non-zero
# exit status of the command
#
# Following options have the same semantics as `FileUtils` method options do
#
# * `:verbose => true` will echo command before execution
#
# * `:noop => true` will just return zero exit status without executing
#   the command
#
# * `:dry_run => true` equivalent to `:verbose => true, :noop => true`
#
module ShellOut
  class ShellOutException < Exception
  end

  CTRL_C_CODE = ?\C-c
  SUCCESS_EXIT_STATUS = 0

  class << self
    def before(*args)
      if args.last.is_a?(Hash)
        options = args.last
        
        verbose, dry_run, noop = options.delete(:verbose), options.delete(:dry_run), options.delete(:noop)
        verbose = noop = true if dry_run

        puts "Executing: #{ args[0..-2].join(" ") }" if verbose

        return false if noop
      end

      true
    end

    def after(exitstatus, out_stream, *args)
      if args.last.is_a?(Hash) && args.last[:raise_exceptions] == true
        unless exitstatus == SUCCESS_EXIT_STATUS
          raise ShellOutException, "`#{ args[0..-2].join(" ") }' command finished with non-zero (#{ exitstatus }) exit status"
        end
      end
      if args.last.is_a?(Hash) && args.last[:out] == :return
        out_stream.rewind if out_stream.is_a?(StringIO)
        out_stream.read
      else
        exitstatus
      end
    end

    def command(*args)
      stripped_command = args.dup
      stripped_command.pop if stripped_command[-1].is_a?(Hash) # remove options
      stripped_command.shift if stripped_command[0].is_a?(Hash) # remove env
      stripped_command.join(" ")
    end

    def with_env(*args)
      yield unless (env = args[0]).is_a?(Hash)
      stored_env = {}
      for name, value in env
        stored_env[name] = ENV[name]
        value == nil ? ENV.delete(name) : ENV[name] = value 
      end
      begin
        yield
      ensure
        for name, value in stored_env
          ENV[name] = value
        end
      end
    end

    def getopt(opt, default, *args)
      if args.last.is_a?(Hash)
        if opt == :out && args.last[:out] == :return
          StringIO.new
        else
          args.last.fetch(opt, default)
        end
      else
        default
      end
    end
  end

  module_function

  def shell_out_with_pty(*args)
    old_state = `stty -g`
    
    return SUCCESS_EXIT_STATUS unless ShellOut::before(*args)

    begin
      # stolen from ruby/ext/pty/script.rb
      # disable echoing and enable raw (not having to press enter)
      system "stty -echo raw lnext ^_"

      in_stream = ShellOut.getopt(:in, STDIN, *args)
      out_stream = ShellOut.getopt(:out, STDOUT, *args)
      writer = nil
      ShellOut.with_env(*args) do
        PTY.spawn(ShellOut.command(*args)) do |r_pty, w_pty, pid|
          reader = Thread.current
          writer = Thread.new do
            while true
              break if (ch = in_stream.getc).nil?
              ch = ch.chr
              if ch == ShellOut::CTRL_C_CODE
                reader.raise Interrupt, "Interrupted by user"
              else
                w_pty.print ch
                w_pty.flush
              end
            end
          end
          writer.abort_on_exception = true

          loop do
            c = begin
              r_pty.sysread(512)
            rescue Errno::EIO, EOFError
              nil
            end
            break if c.nil?

            out_stream.print c
            out_stream.flush
          end

          begin
            # try to invoke waitpid() before the signal handler does it
            return ShellOut::after(Process::waitpid2(pid)[1].exitstatus, out_stream, *args)
          rescue Errno::ECHILD
            # the signal handler managed to call waitpid() first;
            # PTY::ChildExited will be delivered pretty soon, so just wait for it
            sleep 1
          end
        end
      end
    rescue PTY::ChildExited => e
      return ShellOut::after(e.status.exitstatus, out_stream, *args)
    ensure
      writer && writer.kill
      system "stty #{ old_state }"
    end
  end

  def shell_out_with_system(*args)
    return SUCCESS_EXIT_STATUS unless ShellOut::before(*args)

    cleaned_args = if args.last.is_a?(Hash)
      cleaned_options = args.last.dup.delete_if { |k, | [ :verbose, :raise_exceptions ].include?(k) }
      require "stringio"
      if cleaned_options[:out].is_a?(StringIO) ||
              cleaned_options[:out] == :return
        r, w = IO.pipe
        cleaned_options[:out] = w
        cleaned_options[:err] = [ :child, :out ]
      end
      if cleaned_options[:in].is_a?(StringIO)
        in_r, in_w = IO.pipe
        in_w.write cleaned_options[:in].read
        in_w.close
        cleaned_options[:in] = in_r
      end
      cleaned_options.empty? ? args[0..-2] : args[0..-2].dup << cleaned_options
    else
      args
    end

    exitstatus = if Kernel.system(*cleaned_args)
      SUCCESS_EXIT_STATUS
    else
      require "English"
      $CHILD_STATUS.exitstatus
    end

    if r
      w.close
      unless args.last[:out] == :return
        args.last[:out] << r.read
      end
    end

    ShellOut::after(exitstatus, r, *args)
  end

  begin
    require "pty"
    alias shell_out shell_out_with_pty
  rescue LoadError
    alias shell_out shell_out_with_system
  end

  module_function :shell_out
end

def ShellOut(*args)
  ShellOut.shell_out(*args)
end

if $PROGRAM_NAME == __FILE__
  require "spec"
  require "stringio"
  require "./io_interceptor.rb"

  describe "ShellOut" do
    before do
      STDOUT.extend(IoInterceptor)
    end

    share_examples_for "having base capabilities" do

      it "shells out to successful command and returns 0 exit code" do
        ShellOut("ruby -e ''").should == 0
      end

      it "passes arbitrary exit codes" do
        ShellOut("ruby -e 'exit(42)'").should == 42
      end

      it "passes STDIN (or options[:in]) stream to the command" do
        fake_stdin = StringIO.new
        fake_stdin.write "testing\n"
        fake_stdin.rewind

        STDOUT.supress do # TODO still mystery why "testing\n" gets written to the output 
          ShellOut("ruby -e 'exit(123) if gets.chomp == \"testing\"'", :in => fake_stdin).should == 123
        end
      end

      it "alters command environment when first argument is a Hash" do
        ShellOut({ "ENV_VAR" => "42" }, 
                 "ruby -e 'puts ENV.inspect'",
                 :out => :return).should include('"ENV_VAR"=>"42"')
      end

      describe ":raise_exceptions option" do
        it "raises exception for non-zero exit codes" do
          lambda do
            ShellOut("false", :raise_exceptions => true)
          end.should raise_error(ShellOut::ShellOutException)
        end

        it "raises exception for non-existing command" do
          lambda do
            ShellOut("nonexisting", :raise_exceptions => true)
          end.should raise_error(ShellOut::ShellOutException)
        end
      end

      describe ":out option" do
        it "redirects output of command" do
          fake_stdout = StringIO.new
          ShellOut("echo 42", :out => fake_stdout)
          fake_stdout.string.chomp.should == "42"
        end
      end

      describe ":out => :return option" do
        it "return the output of command" do
          ShellOut("echo 42", :out => :return).chomp.should == "42"
        end

        it "return STDERR output of command" do
          ShellOut("ruby -e 'STDERR.puts 42'", :out => :return).chomp.should == "42"
        end
      end

      describe ":verbose option" do
        it "echoes the command name" do
          STDOUT.intercept { ShellOut("true", :verbose => true) }.should include("true")
        end
      end

      def with_vanishing_file(f)
        yield
      ensure
        File.delete(f) rescue nil
      end

      describe ":noop option" do
        it "always returns 0 status" do
          ShellOut("ruby -e 'exit 123'", :noop => true).should == 0
        end

        it "never executes command" do
          f = "never_executes_command.test"
          with_vanishing_file(f) do
            ShellOut("touch #{ f }", :noop => true)
            File.exist?(f).should == false
          end
        end
      end

      describe ":dry_run option" do
        it "echoes the command name" do
          STDOUT.intercept { ShellOut("true", :dry_run => true) }.should include("true")
        end

        it "always returns 0 status" do
          STDOUT.supress { ShellOut("ruby -e 'exit 123'", :dry_run => true) }.should == 0
        end

        it "never executes command" do
          f = "never_executes_command.test"
          with_vanishing_file(f) do
            STDOUT.supress { ShellOut("touch #{ f }", :dry_run => true) }
            File.exist?(f).should == false
          end
        end
      end
    end

    describe "#shell_out_with_system" do
      before do
        def ShellOut(*args)
          ShellOut.shell_out_with_system(*args);
        end
      end

      it_should_behave_like "having base capabilities"
    end

    describe "#shell_out_with_pty" do
      begin
        require "pty"
        before do
          def ShellOut(*args)
            ShellOut.shell_out_with_pty(*args);
          end
        end

        it_should_behave_like "having base capabilities"

        it "uses pseudo-tty" do
          ShellOut("ruby -e 'exit(123) if [STDIN, STDOUT, STDERR].all? { |stream| stream.tty? }'").should == 123
        end

        it "shows the output of the executing command on own STDOUT" do
          STDOUT.intercept { ShellOut("echo '42'") }.should include("42")
        end

        it "doesn't pass Ctrl-C to the command and raises Interrupt exception when Ctrl-C is sent" do
          fake_stdin = StringIO.new
          fake_stdin.write ShellOut::CTRL_C_CODE
          fake_stdin.rewind
          int_trap = "ruby -e 'trap(\"INT\") { puts \"SIGINT received\" }; sleep 999'"
          lambda do
            ShellOut(int_trap, :in => fake_stdin)
          end.should raise_error(Interrupt)

          fake_stdin = StringIO.new
          fake_stdin.write ShellOut::CTRL_C_CODE
          fake_stdin.rewind
          STDOUT.intercept do
            begin
              ShellOut(int_trap, :in => fake_stdin)
            rescue Interrupt
            end
          end.should_not include("SIGINT received")
        end
      rescue LoadError
        it "cannot be tested because 'pty' is not available on this system"
      end
    end
  end

  exit ::Spec::Runner::CommandLine.run
end