require "fileutils"
require "reflexive"
require "open-uri"

def sh(*args)
  require File.expand_path("../shell_out", __FILE__)
  shell_out_args = args.dup
  options = shell_out_args.pop if shell_out_args[-1].is_a?(Hash)
  shell_out_args << { :raise_exceptions => true,
                      :verbose => true }.merge(options || {})
  ShellOut(*shell_out_args)
end

def tmp_gemset_env
  { "GEM_HOME" => $tmp_gemdir,
    "GEM_PATH" => $tmp_gemdir }  
end

def sh_in_tmp_gemset(cmd, options = {})
  sh(tmp_gemset_env, cmd, options)
end

$purge_at_exit = []

at_exit do
  for dir in $purge_at_exit
    FileUtils::Verbose.rm_rf(dir)
  end
end

def mktmpdir(prefix)
  tmp_dir = Dir.mktmpdir
  $purge_at_exit << tmp_dir.dup
  tmp_dir
end

def gem_repository_option
  gem_repository_path = File.expand_path("../../tmp/gem_repository", __FILE__)
  
  if File.directory?(gem_repository_path)
    "--source file://#{ gem_repository_path }"
  else
    ""
  end
end

def bootstrap_gem_environment(*args)
  $tmp_gemdir = mktmpdir("reflexive_test_gemset") 
  while name = args.shift
    version = args.shift
    sh_in_tmp_gemset "gem install #{ name } --version='#{ version }' " <<
                     "--no-update-sources --quiet #{ gem_repository_option }"
  end
end

def make_tmp_gemset_name
  t = Time.now.strftime("%Y%m%d")
  "reflexive_test_gemset_#{t}_#{$$}_#{rand(0x100000000).to_s(36)}"
end

def build_and_install_test_gem
  Dir.chdir(File.expand_path("../../", __FILE__)) do
    sh({ "GEM_VERSION" => "9.9.9" }, "gem build reflexive.gemspec")
    begin
      sh_in_tmp_gemset("gem install reflexive-9.9.9.gem --quiet")
    ensure
      File.delete("reflexive-9.9.9.gem")
    end
  end
end

SERVER_STARTUP_TIME = 20
def spawn_server_and_wait_for_response(cmd)
  $server_pid = spawn(tmp_gemset_env, cmd)
  begin
    trap("CLD") { raise "Failed to start server: server died prematurely" }
    puts "Spawned server with #{ $server_pid } PID"
    tries = 0
    print "Waiting for server to start..."
    started = false
    while (tries += 1) < SERVER_STARTUP_TIME && !started
      started = get("/").include?("Welcome aboard") rescue false
      print "."
      sleep 1
    end
    print "\n"
    unless started
      raise "Failed to start server: server didn't respond in #{ SERVER_STARTUP_TIME } seconds"
    end
  rescue Exception => e
    raise e.exception("Failed to start server: #{ e.message }")
  ensure
    trap("CLD", nil)
  end
end

def terminate_server_blocking
  puts "Terminating server with #{ $server_pid } PID..."
  `kill -9 #{ $server_pid }`
  Process::waitpid2($server_pid) rescue nil
end

def get(path)
  open("http://localhost:3000#{ path }").read
end

def create_rails_app(version)
  unless $tmp_dir # one dir is enough
    $tmp_dir = mktmpdir("reflexive_test_rails_apps")
  end
  
  $app_dir = File.join($tmp_dir, "reflexive_test_rails#{ version }_app")
  
  Dir.chdir($tmp_dir) do
    sh_in_tmp_gemset("rails reflexive_test_rails#{ version }_app")
  end
end

def patch_app_file(path, pattern, replacement)
  Dir.chdir($app_dir) do
    contents = IO.read(path)
    contents.sub!(pattern, replacement)
    File.open(path, "w") { |f| f.write(contents) }
  end
end
