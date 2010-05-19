class Module
  if RUBY_VERSION > '1.9.1'
    alias reflexive_public_instance_methods public_instance_methods
    alias reflexive_private_instance_methods private_instance_methods
    alias reflexive_protected_instance_methods protected_instance_methods
  else
    # Try to workaround 1.9.1 *_instance_methods issues
    def reflexive_public_instance_methods(inc_super = true)
      if inc_super
        public_instance_methods(true)
      else
        methods = public_instance_methods(false)
        methods -= Module.public_instance_methods(false) unless self === Module
        methods -= Class.public_instance_methods(false) unless self === Class
#        ancestors.each do |ancestor|
#          methods -= ancestor.public_instance_methods(false)
#        end
        methods
      end
    end

    def reflexive_protected_instance_methods(inc_super = true)
      if inc_super
        protected_instance_methods(true)
      else
        methods = protected_instance_methods(false)
        methods -= Module.protected_instance_methods(false) unless self === Module
        methods -= Class.protected_instance_methods(false) unless self === Class
        methods
      end
    end

    def reflexive_private_instance_methods(inc_super = true)
      if inc_super
        private_instance_methods(true)
      else
        methods = private_instance_methods(false)
        methods -= Module.private_instance_methods(false) unless self === Module
        methods -= Class.private_instance_methods(false) unless self === Class
        methods
      end
    end
  end
end