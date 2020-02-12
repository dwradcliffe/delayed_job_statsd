FROM ruby:2.5-alpine

RUN apk add --no-cache \
  ruby \
  ruby-dev \
  build-base \
  postgresql-client \
  postgresql-dev \
  bash \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /app
WORKDIR /app

COPY . /app

RUN gem install bundler && bundle install --jobs 20 --retry 5

ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "/app/run.rb"]
