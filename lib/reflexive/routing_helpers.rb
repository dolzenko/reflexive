module RoutingHelpers
  def dashboard_path
    "/reflexive/dashboard"
  end

  def up_path(path)
    file_path(File.expand_path("../", path))
  end

  def file_path(path)
    File.join("/reflexive/files", path)
  end

  def constant_path(constant)
    "/reflexive/constants/#{ constant }"
  end

  def method_path(constant, method_name)
    "/reflexive/constants/#{ constant }/methods/#{ Rack::Utils.escape method_name }"
  end

  def new_method_path(constant, level, method_name)
    "/reflexive/constants/#{ constant }/#{ level }_methods/#{ Rack::Utils.escape method_name }"
  end

  def apidock_path(constant, method_name)
    "http://apidock.com/ruby/#{ constant }/#{ Rack::Utils.escape method_name }"
  end

  def method_definition_path(constant, method_name)
    method_path(constant, method_name) + "/definition"
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
end