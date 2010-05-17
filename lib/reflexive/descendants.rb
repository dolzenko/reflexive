module Reflexive
  module_function
  
  # List all descedents of this class.
  #
  #   class X ; end
  #   class A < X; end
  #   class B < X; end
  #   X.descendents  #=> [A,B]
  #
  # You may also limit the generational distance
  # the subclass may be from the parent class.
  #
  #   class X ; end
  #   class A < X; end
  #   class B < A; end
  #   X.descendents    #=> [A, B]
  #   X.descendents(1) #=> [A]
  #
  # NOTE: This is a intensive operation. Do not
  # expect it to be super fast.

  def descendants(klass, generations=nil)
    subclass = []
    
    ObjectSpace.each_object(Class) do |c|
      next if c == klass
      
      ancestors = c.ancestors[0 .. (generations || -1)]
      subclass << c if ancestors.include?(klass)

      ancestors = c.singleton_class.ancestors[0 .. (generations || -1)]
      subclass << c if ancestors.include?(klass)
    end
    
    subclass
  end
end

