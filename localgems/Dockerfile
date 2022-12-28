FROM ruby:3.2.0-bullseye
COPY . /myapp
WORKDIR /myapp/mel-mnbme
RUN gem install rake
RUN bundle install
RUN rake install
