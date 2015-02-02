## Rails demo app

~~~
gem install rails
~~~

~~~
rails new . --skip-active-record
~~~

**config/application.rb**

~~~ruby
require "neo4j/railtie"
~~~

~~~
rake neo4j:install[community-2.1.6]
rake neo4j:install[community-2.1.6,test]
~~~

~~~
rake neo4j:config[test,7475]
~~~

~~~
rake neo4j:start
rake neo4j:start[test]
~~~
