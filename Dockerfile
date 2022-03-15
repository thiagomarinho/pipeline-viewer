FROM ruby:3.0.2-slim

COPY . /app

WORKDIR /app

RUN bundle install

RUN ruby /app/app.rb
