#!/bin/bash

# run docker registry container
# https://github.com/curtiszimmerman/docker-registry-auth

docker run -d \
  --name="docker-registry-auth" \
  --restart="always" \
  -p 5000:5000 \
  docker-registry-auth
