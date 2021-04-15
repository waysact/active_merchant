FROM ruby:2.6.6-slim

WORKDIR /app

RUN apt-get -qqy update && apt-get install -qy build-essential git-core

ADD . .
RUN bundle install --jobs=$(nproc) --retry=3 --gemfile gemfiles/Gemfile.rails60
