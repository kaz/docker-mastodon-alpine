FROM alpine

RUN apk add \
		git build-base \
		nodejs yarn \
		ruby ruby-bundler ruby-json ruby-bigdecimal ruby-dev \
		zlib-dev openssl-dev postgresql-dev icu-dev protobuf-dev libidn-dev

ARG MASTODON_VERSION=v3.2.2
RUN mkdir -p /opt/mastodon &&\
	wget -O- https://github.com/tootsuite/mastodon/archive/$MASTODON_VERSION.tar.gz | tar zxvf - -C /opt/mastodon --strip-components 1

WORKDIR /opt/mastodon
RUN bundle config set deployment "true" &&\
	bundle config set without "development test" &&\
	bundle install -j$(nproc)
RUN mkdir -p /usr/local/share/.config/yarn/global/ &&\
	touch /usr/local/share/.config/yarn/global/.yarnclean &&\
	yarn install --pure-lockfile

FROM alpine

ARG UID=991
RUN printf "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)\n%.0s" 1 2 | adduser -u $UID -h /opt/mastodon mastodon &&\
	ln -s /opt/mastodon /mastodon &&\
	apk --no-cache add \
		tini libc6-compat imagemagick ffmpeg file ca-certificates tzdata \
		nodejs yarn \
		ruby ruby-bundler ruby-json ruby-bigdecimal \
		zlib libssl1.1 libpq icu-libs libprotobuf libidn

COPY --from=0 --chown=mastodon:mastodon /opt/mastodon /opt/mastodon

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/lib64"
ENV PATH="${PATH}:/opt/mastodon/bin"
ENV RAILS_ENV="production"
ENV NODE_ENV="production"
ENV RAILS_SERVE_STATIC_FILES="true"
ENV BIND="0.0.0.0"

USER mastodon
WORKDIR /opt/mastodon
RUN OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile &&\
	yarn cache clean

ENTRYPOINT ["/sbin/tini", "--"]
EXPOSE 3000 4000
