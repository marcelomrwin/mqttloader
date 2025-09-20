#!/bin/bash
set -e

: ${MQTT_BROKER:=""}
: ${MQTT_BROKER_PORT:="1883"}
: ${MQTT_VERSION:="5"}
: ${MQTT_NUM_PUBLISHERS:="1"}
: ${MQTT_NUM_SUBSCRIBERS:="1"}
: ${MQTT_QOS_PUBLISHER:="0"}
: ${MQTT_QOS_SUBSCRIBER:="0"}
: ${MQTT_SHARED_SUBSCRIPTION:="false"}
: ${MQTT_RETAIN:="false"}
: ${MQTT_TOPIC:="mqttloader-test-topic"}
: ${MQTT_PAYLOAD:="20"}
: ${MQTT_NUM_MESSAGES:="100"}
: ${MQTT_RAMP_UP:="0"}
: ${MQTT_RAMP_DOWN:="0"}
: ${MQTT_INTERVAL:="0"}
: ${MQTT_SUBSCRIBER_TIMEOUT:="5"}
: ${MQTT_EXEC_TIME:="60"}
: ${MQTT_LOG_LEVEL:="INFO"}

if [[ -z "$MQTT_BROKER" ]]; then
    echo "ERROR: MQTT_BROKER environment variable is required"
    exit 1
fi

: ${MQTT_NTP:="es.pool.ntp.org"}

if [[ -n "$MQTT_NTP" ]]; then
    export MQTT_NTP_LINE="ntp = $MQTT_NTP"
else
    export MQTT_NTP_LINE="ntp = es.pool.ntp.org"
fi

if [[ -n "$MQTT_OUTPUT" ]]; then
    export MQTT_OUTPUT_LINE="output = $MQTT_OUTPUT"
else
    export MQTT_OUTPUT_LINE="# output = ."
fi

if [[ -n "$MQTT_USER_NAME" ]]; then
    export MQTT_USER_NAME_LINE="user_name = $MQTT_USER_NAME"
else
    export MQTT_USER_NAME_LINE="# user_name = "
fi

if [[ -n "$MQTT_PASSWORD" ]]; then
    export MQTT_PASSWORD_LINE="password = $MQTT_PASSWORD"
else
    export MQTT_PASSWORD_LINE="# password = "
fi

if [[ -n "$MQTT_TLS" ]]; then
    export MQTT_TLS_LINE="tls = $MQTT_TLS"
else
    export MQTT_TLS_LINE="# tls = false"
fi

if [[ -n "$MQTT_TLS_ROOTCA_CERT" ]]; then
    export MQTT_TLS_ROOTCA_CERT_LINE="tls_rootca_cert = $MQTT_TLS_ROOTCA_CERT"
else
    export MQTT_TLS_ROOTCA_CERT_LINE="# tls_rootca_cert = "
fi

if [[ -n "$MQTT_TLS_CLIENT_KEY" ]]; then
    export MQTT_TLS_CLIENT_KEY_LINE="tls_client_key = $MQTT_TLS_CLIENT_KEY"
else
    export MQTT_TLS_CLIENT_KEY_LINE="# tls_client_key = "
fi

if [[ -n "$MQTT_TLS_CLIENT_CERT_CHAIN" ]]; then
    export MQTT_TLS_CLIENT_CERT_CHAIN_LINE="tls_client_cert_chain = $MQTT_TLS_CLIENT_CERT_CHAIN"
else
    export MQTT_TLS_CLIENT_CERT_CHAIN_LINE="# tls_client_cert_chain = "
fi

envsubst < /app/mqttloader.template.conf > /app/mqttloader.conf

echo "Configuration file generated successfully"
