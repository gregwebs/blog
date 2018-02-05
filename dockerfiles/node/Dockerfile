FROM node:9.4.0-alpine

ENV LANG   C.UTF-8
ENV LC_ALL C.UTF-8
ENV PATH=./node_modules/.bin:$PATH

# Install git
# Install download helper
RUN apk update \
 && apk add git \
 && apk add make binutils g++ python vips-dev fftw-dev --update-cache --repository https://dl-3.alpinelinux.org/alpine/edge/testing/ \
 && apk add ca-certificates wget \
 && update-ca-certificates

# Handle signals properly
RUN wget -O /usr/local/bin/dumb-init \
  https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64
RUN chmod +x /usr/local/bin/dumb-init

# Define entrypoint
ENTRYPOINT ["/usr/local/bin/dumb-init"]

# Expose ports.
EXPOSE 80
EXPOSE 443
