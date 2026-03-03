#!/bin/bash

docker run -p 8080:8080 \
  -e GLOBAL_PORT=8080 \
  -e GLOBAL_MAX_BODY_SIZE=50m \
  -e ROUTE_1_PATH="/prometheus" \
  -e ROUTE_1_DEST="http://prometheus:9090/" \
  -e ROUTE_1_HEADERS="X-Env test" \
  -e ROUTE_2_PATH="/api" \
  -e ROUTE_2_DEST="http://backend:8080/" \
  dynamic-nginx-proxy
``