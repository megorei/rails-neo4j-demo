FROM rails:onbuild
ENV RAILS_ENV production
ENV NEO4J_URL http://neo4j:7474/
ENV SECRET_KEY_BASE 10a7d0d6a27e29644a38927f3f4e4553e9d24b5fdcc11d5581316924c58a3a94297493c8a5cd27d8c09e9a3c88263c75ab0d2a7fe63cc3f39acc7574dee60cc2

RUN DISABLE_NEO4J_SESSION=true bundle exec rake assets:precompile