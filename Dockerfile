FROM ruby:3.4.1-alpine

WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install
COPY . /app/

CMD ["ruby", "generate_markdown.rb"]
