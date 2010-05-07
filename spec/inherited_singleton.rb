class A
  def self.a
    puts "A"
  end
end

module M
  def a
    puts "M"
    super
  end
end

class C < A
  extend M
  def self.a
    puts "C"
    super
  end
end

trite_singleton_ancestors = Class.new.singleton_class.ancestors
trite_ancestors = Class.new.ancestors

ancestors = []
for ancestor in (C.ancestors - trite_ancestors)
  ancestors << ancestor
  singleton = ancestor.singleton_class
  singleton_ancestors = [ singleton ] + singleton.ancestors
  original_singleton_ancestors = singleton_ancestors - trite_singleton_ancestors

  for singleton_ancestor in original_singleton_ancestors
    ancestors << singleton_ancestor
  end
end

puts ancestors.inspect