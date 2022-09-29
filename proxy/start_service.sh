#!/bin/sh
/usr/sbin/nginx -g  "daemon off;" &
envoy -c /etc/envoy/envoy.yaml # --service-cluster "test"
