K = SingletonVisibility
def debug
  if K.respond_to?(:test)
    K.test
  elsif K.respond_to?(:new) && K.new.respond_to?(:test)
    K.new.test
  end

  puts "Inspecting: #{ K.name }"
  puts "* ancestors: #{ K.ancestors.inspect }"

  omit = proc { |klass| [Class, Module, Object, Kernel, BasicObject].include?(klass) }

  for k in K.ancestors
    puts "  " + k.name
    if omit[k]
      # puts "    ...omitted..."
      next
    end
    for m in %w( singleton_methods methods public_instance_methods protected_instance_methods private_instance_methods)
      puts "    #{ m }(false): #{ k.send(m, false).inspect }"
      # puts "    #{ m }(true): #{ k.send(m, true).inspect }"
    end
  end

  puts "---"
  puts "* singleton_class.ancestors: #{ ([ K.singleton_class ] + K.singleton_class.ancestors).inspect }"
  for k in ([ K.singleton_class ] + K.singleton_class.ancestors)
    puts "  " + (k.name || "singleton crap")
    if omit[k]
      # puts "    ...omitted..."
      next
    end
    for m in %w( singleton_methods methods public_instance_methods protected_instance_methods instance_methods private_instance_methods)
      puts "    #{ m }(false): #{ k.send(m, false).inspect }"
      # puts "    #{ m }(true): #{ k.send(m, true).inspect }"
    end
  end
end

def test_singleton_methods_false_equals_to_public_methods_false
  @klasses = []
  ObjectSpace.each_object do |object|
    @klasses << object.class unless @klasses.include?(object.class)
  end

  # Invariant:
  # k.singleton_methods(false) == k.public_methods(false) when k == Class
  # and these are class methods defined immediately in k (not by `extend`)
  for k in @klasses
    puts k.name if k.singleton_methods(false) != k.public_methods(false)
  end
end

# `k.singleton_class.public_instance_methods(false)` are class methods
# available for k mixed in from other modules

# ??? `methods == public_methods`

# Unless Module has singleton method defined `M.public_methods(false)` returns
# something weird, while `M.methods(false)` seem to be consistent

def test_singleton_ancestors
  @klasses = []
  ObjectSpace.each_object do |object|
    @klasses << object.class unless @klasses.include?(object.class)
  end

  trite = [Class, Module, Object, Kernel, BasicObject]
  for k in @klasses
    ancestors = k.singleton_class.ancestors
    next if ancestors == trite
    puts "#{ k.name }.singleton_class.ancestors: #{ ancestors.inspect }"
  end
end

# Invariant:
# k.singleton_methods(false) == k.singleton_class.instance_methods(false)

#require "yaml"
#require "active_support/all"
#require "active_record"

#K = YAML

# require "rails/all"

def files(k, methods, method_method = :method)
  locations = methods.map { |m| k.send(method_method, m).source_location rescue raise([k,methods].inspect)}.compact
  locations.map { |l| l[0] }.uniq
end

def inspecting
  puts "Inspecting: #{ K.name }"
  puts "* ancestors: #{ K.ancestors.inspect }"

  omit = proc { |klass| [Class, Module, Object, Kernel, BasicObject].include?(klass) }

  for k in K.ancestors
    puts "  " + k.name
    if omit[k]
      # puts "    ...omitted..."
      next
    end
    class_methods = k.singleton_methods(false)
    class_method_files = files(k, class_methods)
    class_methods.concat k.singleton_class.public_instance_methods(false)
    puts "    Class: #{ class_methods.sort.inspect }"
    puts "      files: #{ class_method_files.sort.inspect }"


    instance_files = []
    instance_methods = %w( public_instance_methods
                        protected_instance_methods
                        private_instance_methods ).map do |m|
      methods = k.send(m, false)
      instance_files.concat files(k, methods, :instance_method) #rescue nil
      instance_files.uniq!
      methods
    end.flatten
    puts "    Instance: #{ instance_methods.sort.inspect }"
    puts "      files: #{ instance_files.sort.inspect }"
  end
end

def singleton_anc
  k = DateTime.singleton_class.ancestors[0]
  puts files(k, k.methods)
  puts files(k, k.methods, :instance_method)
  k = DateTime.singleton_class.ancestors[1]
  puts files(k, k.methods)
  puts files(k, k.methods, :instance_method)
end


#require "pp"
#
#module SA
#  def sa
#  end
#end

#class A
#  extend SA
#end
#
#module SB
#  def sb
#  end
#end
#
#class B < A
#  extend SB
#end
#
#class C < B
#end
#
#class D < C
#end



#module M
#  def mixedin
#
#  end
#end
#
#module MC
#  def class_mixedin
#
#  end
#end
#
#class B
#  include M
#  extend MC
#
#  def self.class_inherited
#
#  end
#
#  class << self
#    protected
#    def class_inherited_protected
#
#    end
#
#    private
#    def class_inherited_private
#
#    end
#  end
#
#  def inherited
#
#  end
#end
#
#module MiddleMC
#  def middlemc
#  end
#end
#
#class Middle < B
#  extend MiddleMC
#  def self.middle_class
#  end
#end
#
#class C < Middle
#  def self.class_public
#
#  end
#  class << self
#    protected
#    def class_protected
#
#    end
#
#    private
#    def class_private
#
#    end
#  end
#  public
#  def public
#
#  end
#
#  private
#  def private
#
#  end
#
#  protected
#  def protected
#
#  end
#end

#module MBB
#  def self.mbb_class_method
#
#  end
#
#  def mbb_instance_method
#
#  end
#end
#
#module MB
#  include MBB
#
#  def self.mb_class_method
#
#  end
#
#  def mb_instance_method
#
#  end
#end
#
#module M
#  include MB
#
#  def self.class_method
#
#  end
#
#  def method
#
#  end
#end

# pp Methods.new(M).all

# M.mb_instance_method

#C.class_mixedin