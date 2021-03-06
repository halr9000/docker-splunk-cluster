#!/bin/bash

mkdir -p $SPLUNK_HOME/var/consul

/bin/consul \
    agent \
    -data-dir="$SPLUNK_HOME/var/consul" \
    -retry-join="${CONSUL_HOST:-consul}" \
    -dc="${CONSUL_DC:-dc}" \
    -domain="${CONSUL_DOMAIN:-splunk}" \
    -advertise=$(ip addr list ${CONSUL_ADVERTISE_INTERFACE:-eth0} |grep "inet " |cut -d' ' -f6|cut -d/ -f1)
