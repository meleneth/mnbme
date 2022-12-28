FROM ruby:3.2.0-bullseye as gem-cache
RUN mkdir -p /usr/local/bundle
RUN gem install bundler:2.4.1

FROM gem-cache AS gems
WORKDIR /myapp
COPY localgems/* /myapp
WORKDIR /myapp/mel-mnbme
RUN bundle install
RUN rake install

FROM gem-cache as final
COPY --from=gems /usr/local/bundle /usr/local/bundle

WORKDIR /myapp
COPY gameservice/Gemfile ./
COPY gameservice/Gemfile.lock ./
RUN bundle install
COPY gameservice/* /myapp

# Add a script to be executed every time the container starts.
ENTRYPOINT ["rackup", "-o", "gameservice"]
EXPOSE 9292
