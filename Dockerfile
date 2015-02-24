FROM rails:onbuild
ENV RAILS_ENV production
ENV NEO4J_URL http://neo4j:7474/

ADD .env /usr/src/app/

RUN DISABLE_NEO4J_SESSION=true bundle exec rake assets:precompile