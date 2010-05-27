require "reflexive/routing_helpers"

class Method
  def reflexive_url
    level = receiver.instance_of?(Class) ? :class : :instance
    klass = receiver.instance_of?(Class) ? receiver : receiver.class
    Reflexive::Application.default_url_prefix +
      Reflexive::RoutingHelpers.new_method_path(klass, level, name)
  end
end

class UnboundMethod
  def reflexive_url
    Reflexive::Application.default_url_prefix +
      Reflexive::RoutingHelpers.new_method_path(owner, :instance, name)
  end
end

class Class
  def reflexive_url
    Reflexive::Application.default_url_prefix +
      Reflexive::RoutingHelpers.constant_path(self)
  end
end

class Module
  def reflexive_url
    Reflexive::Application.default_url_prefix +
      Reflexive::RoutingHelpers.constant_path(self)
  end
end