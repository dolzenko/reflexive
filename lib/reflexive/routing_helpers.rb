require "cgi" unless defined?(CGI) && defined?(CGI::escape)

module RoutingHelpers
  # method_call_tag is the scanner event tag emitted by ReflexiveRipper
  def method_call_path(method_call_tag)
    # r method_call_tag.values_at(:name, :receiver)
    name, receiver = method_call_tag.values_at(:name, :receiver)
    if receiver.last == :instance
      new_method_path(receiver[0..-2].join("::"), :instance, name)
    else
      new_method_path(receiver.join("::"), :class, name)
    end rescue(r(method_call_tag)) 
  end

  # entry point for method links (may dispatch to
  # class_method_definition_path or method_documentation_path based on whether
  # the method definition was found by with our reflection capabilities)
  def new_method_path(constant, level, method_name)
    "/reflexive/constants/#{ constant }/#{ level }_methods/#{ CGI.escape(method_name.to_s) }"
  end

  def class_method_definition_path(constant, method_name)
    new_method_path(constant, :class, method_name) + "/definition"
  end

  def instance_method_definition_path(constant, method_name)
    new_method_path(constant, :instance, method_name) + "/definition"
  end

  def method_documentation_path(constant, method_name)
    method_path(constant, method_name) + "/apidock"
  end

  def dashboard_path
    "/reflexive/dashboard"
  end

  def up_path(path)
    file_path(File.expand_path("../", path))
  end

  def file_path(path)
    File.join("/reflexive/files", path)
  end

  def constant_lookup_path(name, scope)
    "/reflexive/constant_lookup" <<
      "?name=#{ CGI.escape(name) }&scope=#{ CGI.escape(scope.join("::"))}"
  end

  def load_path_lookup_path(path)
    "/reflexive/load_path_lookup?path=#{ CGI.escape(path.to_s) }"
  end

  def constant_path(constant)
    "/reflexive/constants/#{ constant }"
  end

  def method_path(constant, method_name)
    "/reflexive/constants/#{ constant }/methods/#{ CGI.escape(method_name.to_s) }"
  end

  def apidock_path(constant, method_name)
    "http://apidock.com/ruby/#{ constant }/#{ CGI.escape(method_name.to_s) }"
  end

  def method_definition_path(constant, method_name)
    method_path(constant, method_name) + "/definition"
  end
end