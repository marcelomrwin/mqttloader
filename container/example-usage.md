# MQTTLoader Container Usage Examples

## Build the container
```bash
podman build -f container/Containerfile -t mqttloader .
```

## Basic usage with environment variables
```bash
podman run --rm \
  -e MQTT_BROKER=broker.hivemq.com \
  -e MQTT_BROKER_PORT=1883 \
  -e MQTT_NUM_MESSAGES=50 \
  mqttloader
```

## Advanced usage with TLS and authentication
```bash
podman run --rm \
  -e MQTT_BROKER=test.mosquitto.org \
  -e MQTT_BROKER_PORT=8883 \
  -e MQTT_TLS=true \
  -e MQTT_USER_NAME=testuser \
  -e MQTT_PASSWORD=testpass \
  -e MQTT_NUM_PUBLISHERS=2 \
  -e MQTT_NUM_SUBSCRIBERS=2 \
  -e MQTT_NUM_MESSAGES=1000 \
  mqttloader
```

## With output directory mounted
```bash
podman run --rm \
  -v ./output:/app/output \
  -e MQTT_BROKER=broker.hivemq.com \
  -e MQTT_OUTPUT=/app/output \
  -e MQTT_NUM_MESSAGES=100 \
  mqttloader
```

## All available environment variables
- MQTT_BROKER (required)
- MQTT_BROKER_PORT (default: 1883)
- MQTT_VERSION (default: 5)
- MQTT_NUM_PUBLISHERS (default: 1)
- MQTT_NUM_SUBSCRIBERS (default: 1)
- MQTT_QOS_PUBLISHER (default: 0)
- MQTT_QOS_SUBSCRIBER (default: 0)
- MQTT_SHARED_SUBSCRIPTION (default: false)
- MQTT_RETAIN (default: false)
- MQTT_TOPIC (default: mqttloader-test-topic)
- MQTT_PAYLOAD (default: 20)
- MQTT_NUM_MESSAGES (default: 100)
- MQTT_RAMP_UP (default: 0)
- MQTT_RAMP_DOWN (default: 0)
- MQTT_INTERVAL (default: 0)
- MQTT_SUBSCRIBER_TIMEOUT (default: 5)
- MQTT_EXEC_TIME (default: 60)
- MQTT_LOG_LEVEL (default: INFO)
- MQTT_NTP (optional)
- MQTT_OUTPUT (optional)
- MQTT_USER_NAME (optional)
- MQTT_PASSWORD (optional)
- MQTT_TLS (optional)
- MQTT_TLS_ROOTCA_CERT (optional)
- MQTT_TLS_CLIENT_KEY (optional)
- MQTT_TLS_CLIENT_CERT_CHAIN (optional)
