## Reflexive

Reflexive is a web based live class and source code browser. It's meant to simplify
navigating the code bases which make heavy use of metaprogramming techniques
and/or have large amount of classes dispersed between many files.
Particularly I wrote it to have a better tool to navigate
[Arel](http://github.com/rails/arel) source code.   

*Live* means that it runs next to your loaded application and reflects on the actual
live classes. Since most of the metaprogramming tricks happen at load
time we can get precise information on what the classes are
composed of, which methods they respond etc. That's something that is either
impossible or very hard with the static code analysis tools like RDoc
or YARD.

Reflexive is a Sinatra app and can be used stand-alone or mounted as Rack app
from your Rails application. Reflexive is based on standard 1.9.2 Ruby library
utilizing `Method/UnboundMethod` classes, `methods/instance_methods` methods for reflection and
Ripper parser for code navigation. Checkout [Reflexive: Live Class And Source Code Browser](http://dolzhenko.org/blog/?p=150)
blog post for longer introduction.


### Features

#### Class Browser

Check out sample output for
[Date](http://reflexive-demo.heroku.com/reflexive/constants/Date),
[FileUtils](http://reflexive-demo.heroku.com/reflexive/constants/FileUtils),
[ActiveRecord::Base](http://reflexive-demo.heroku.com/reflexive/constants/ActiveRecord::Base)
classes.

*Note:* demo project is running on Heroku with Ruby 1.9.1 which has some known 
issues with reflection capabilities which are fixed in 1.9.2, consult Ruby 1.9.1 Known Bugs
section for details.

It includes

1. Class ancestor chain

2. Files in which methods of the class were defined

3. Constants nested inside module/class

4. Class descendants

5. Class and instance methods grouped by class/module they're defined in and visibility.
Clicking on any method leads to the method definition opened in Source Browser.

#### Source Browser

Check out sample output for
[uri/common.rb](http://reflexive-demo.heroku.com/reflexive/files/usr/ruby1.9.1/lib/ruby/1.9.1/uri/common.rb),
[ostruct.rb](http://reflexive-demo.heroku.com/reflexive/files/usr/ruby1.9.1/lib/ruby/1.9.1/ostruct.rb),
[rubygems.rb](http://reflexive-demo.heroku.com/reflexive/files/usr/ruby1.9.1/lib/ruby/site_ruby/1.9.1/rubygems.rb) 
files.

Features include: clicking constants will try to open them in Class Browser, method
calls with constant receiver or without explicit receiver will be resolved
according to Method Lookup section and open the target method in Source Browser.
Clicking `blabla` in `require "blabla"` will take you to the `blabla.rb`, and
clicking local variable will highlight the place where the variable was introduced
with acid pink (ouch!) background.

#### Method Call Lookup

Methods called without explicit receiver are searched according to the
following algorithm

1. Look for the method defined by the class

2. Look for methods defined by derived classes or including modules, i.e. by going
down the inheritance tree

3. When all of the above fails last resort lookup which just searches the named
method in all classes.


### Installation

Reflexive requires the most recent version of Ruby you can get.
With [RVM](http://rvm.beginrescueend.com/) installed

    > rvm install ruby-1.9.2-head
    > rvm use ruby-1.9.2-head
    > gem install reflexive


### Usage

#### Rails 3.0.0.beta3 and higher

Add to your application `Gemfile`

    gem "reflexive"

Add to `config/application.rb`

    config.middleware.insert_after("Rack::Lock", "Reflexive::Application")

Run the server in production environment with

    rails server --environment=production

Reflexive Dashboard should be available at
[http://localhost:3000/reflexive/dashboard](http://localhost:3000/reflexive/dashboard)

#### Rails 2.3.x

Add to your application `config/environment.rb` file

    config.gem "reflexive"
    config.middleware.insert_after("Rack::Lock", "Reflexive::Application")

Run the server in production environment with

    ruby script/server --environment=production

Reflexive Dashboard should be available at
[http://localhost:3000/reflexive/dashboard](http://localhost:3000/reflexive/dashboard)

#### Stand-alone

If you want to use Reflexive outside of Rack environment just place
the following lines in your script

    require "reflexive/application"

    Reflexive::Application.run!

This will block execution and start Reflexive as stand-alone Sinatra app.
Reflexive Dashboard should be available at
[http://localhost:4567/reflexive/dashboard](http://localhost:4567/reflexive/dashboard)


### Ruby 1.9.1 Known Bugs

1. Class methods are reported as owned by class even when they are only inherited
(leads to a lot of class methods reported incorrectly)

2. Can't locate methods created with `attr_reader/writer`

### Hacking

    > git clone git://github.com/dolzenko/reflexive.git
    > cd reflexive
    > bundle install # install gems required in development
    > rbdev # place ./lib on $RUBYLIB, see http://gist.github.com/361451#gistcomment-948
    > rake # run specs
    > SINATRA_RELOADER=1 bundle exec rackup -p 4567 -s thin # run development server with class reloading


MIT License. Copyright &copy; 2010 Evgeniy Dolzhenko.
[http://dolzhenko.org](http://dolzhenko.org)