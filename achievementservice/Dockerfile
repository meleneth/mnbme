FROM ruby:3.2.0-bullseye
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp

# Add a script to be executed every time the container starts.
ENTRYPOINT ["rackup", "-o", "achievementservice"]
EXPOSE 9292
