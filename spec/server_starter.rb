module M1
  def self.module_module_meth
  end

  def module_meth
  end

  class << self
    def module_singleton_meth
    end
  end
end

module M2
end

module M3
end

module M4
  def m4_module_meth
  end
end

class C
  include M1
  include M2

  def self.class_class_meth
  end

  def class_meth
  end

  def >(other)

  end

  def <(other)

  end

  class << self
    def class_singleton_meth
    end

    def class_singleton_meth2
    end

    def class_singleton_meth3
    end

    def class_singleton_meth4
    end

    def class_singleton_meth5
    end

    def class_singleton_meth6
    end

    def class_singleton_meth7
    end

    def class_singleton_meth8
    end

    def <(other)
    end
  end

  def class_overriden_meth
  end
end

class D < C
  include M3
  def self.class_class_meth
  end

  def class_overriden_meth
  end

  def d_class_meth
  end
end

class E < D
  include M4
  def self.class_class_meth
  end

  def class_overriden_meth
  end

  def e_class_meth
  end
end

require "reflexive"
Reflexive::Application.run!
