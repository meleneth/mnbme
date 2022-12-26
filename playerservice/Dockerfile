FROM ruby:latest
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY --chmod=0755 ./play.rb /myapp/play.rb

# Add a script to be executed every time the container starts.
CMD ["./play.rb"]

