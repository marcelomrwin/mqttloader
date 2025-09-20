# MQTTLoader Container Build Guide

## Multi-Architecture Build and Push

This guide explains how to build and push multi-architecture container images for MQTTLoader to Quay.io.

### Prerequisites

- Podman installed
- Access to Quay.io registry
- QEMU setup for cross-platform builds (if building on different arch)

### Build Multi-Arch Images

#### 1. Login to Quay.io

```bash
podman login quay.io
```

#### 2. Build for AMD64

```bash
podman build \
  --platform linux/amd64 \
  --file container/Containerfile \
  --tag quay.io/masales/mqttloader:0.8.6-amd64 \
  .
```

#### 3. Build for ARM64

```bash
podman build \
  --platform linux/arm64 \
  --file container/Containerfile \
  --tag quay.io/masales/mqttloader:0.8.6-arm64 \
  .
```

**Important**: Always run these commands from the project root directory, not from the `container/` subdirectory, so the build context includes all necessary files.

#### 4. Push Individual Architecture Images

```bash
podman push quay.io/masales/mqttloader:0.8.6-amd64
podman push quay.io/masales/mqttloader:0.8.6-arm64
```

### Create Multi-Arch Manifest

#### 5. Remove Existing Manifest (if exists)

```bash
podman manifest rm quay.io/masales/mqttloader:0.8.6 2>/dev/null || true
```

#### 6. Create New Manifest

```bash
podman manifest create quay.io/masales/mqttloader:0.8.6
```

#### 7. Add Architecture Images to Manifest

```bash
podman manifest add quay.io/masales/mqttloader:0.8.6 \
  quay.io/masales/mqttloader:0.8.6-amd64

podman manifest add quay.io/masales/mqttloader:0.8.6 \
  quay.io/masales/mqttloader:0.8.6-arm64
```

#### 8. Push Multi-Arch Manifest

```bash
podman manifest push quay.io/masales/mqttloader:0.8.6
```

### Automated Build Script

The `build-podman-multiarch.sh` script handles the complete multi-arch build and push process using the proper manifest workflow. It automatically detects if you're running from the project root or container/ directory and adjusts the build context accordingly.

Usage:

```bash
# From project root
./container/build-podman-multiarch.sh

# From container/ directory  
cd container/
./build-podman-multiarch.sh
```

The script intelligently detects your architecture and builds accordingly:
- **ARM64 host**: Builds multi-arch (AMD64 + ARM64) - emulation works better
- **AMD64 host**: Builds only AMD64 - avoids Gradle emulation issues  
- Remove existing manifest
- Create new manifest
- Build for detected platforms with `--manifest` flag
- Push the final manifest

### Verify Multi-Arch Support

Check the manifest:

```bash
podman manifest inspect quay.io/masales/mqttloader:0.8.6
```

### Usage Examples

Once pushed, users can pull and run on any supported architecture:

```bash
# Pull automatically selects correct architecture
podman pull quay.io/masales/mqttloader:0.8.6

# Basic run with environment variables
podman run --rm \
  -e MQTT_BROKER=broker.hivemq.com \
  -e MQTT_NUM_MESSAGES=50 \
  quay.io/masales/mqttloader:0.8.6
```

## Container Usage Examples

### Basic Usage

```bash
# Run with authentication
podman run --rm -it \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  quay.io/masales/mqttloader:0.8.6
```

### Separated Publishers and Subscribers

Run publishers and subscribers on different containers to avoid mutual influence and better simulate real-world scenarios.

**Important**: Always start the subscriber FIRST so it's ready to receive messages, then start the publisher.

#### Step 1: Start Subscriber Container (First!)
```bash
# Start subscriber first - it will wait for messages
podman run --rm -it \
  --name mqtt-subscriber \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  -e MQTT_NUM_PUBLISHERS=0 \
  -e MQTT_NUM_SUBSCRIBERS=2 \
  -e MQTT_SUBSCRIBER_TIMEOUT=60 \
  -e MQTT_EXEC_TIME=120 \
  -e MQTT_TOPIC=load-test-topic \
  quay.io/masales/mqttloader:0.8.6
```

#### Step 2: Start Publisher Container (Second!)
```bash
# Wait a few seconds, then start publisher
sleep 5

# Container that publishes messages to waiting subscriber
podman run --rm -it \
  --name mqtt-publisher \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  -e MQTT_NUM_PUBLISHERS=2 \
  -e MQTT_NUM_SUBSCRIBERS=0 \
  -e MQTT_NUM_MESSAGES=1000 \
  -e MQTT_TOPIC=load-test-topic \
  quay.io/masales/mqttloader:0.8.6
```

**Best Practices for Distributed Testing:**
- **Start order**: Always start subscriber FIRST, then publisher
- **Subscriber timeout**: Set 2x longer than expected publisher time (90s vs 45s)
- **Exec time**: Give subscriber generous buffer (150s vs expected 60s)  
- **Background execution**: Use `&` to run subscriber in background
- **Coordination delay**: Add `sleep 5-15` before starting publisher
- **Container names**: Use descriptive names for easy monitoring
- **Output capture**: Mount volume on subscriber for result collection

### High-Load Testing with Resource Limits

For robust load testing, configure CPU and memory limits:

```bash
# High-load publisher with resource constraints
podman run --rm -it \
  --cpus="4.0" \
  --memory="2g" \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  -e MQTT_NUM_PUBLISHERS=10 \
  -e MQTT_NUM_SUBSCRIBERS=0 \
  -e MQTT_NUM_MESSAGES=10000 \
  -e MQTT_PAYLOAD=1024 \
  -e MQTT_INTERVAL=1000 \
  -e MQTT_QOS_PUBLISHER=1 \
  quay.io/masales/mqttloader:0.8.6
```

```bash
# High-load subscriber with resource constraints
podman run --rm -it \
  --cpus="4.0" \
  --memory="2g" \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  -e MQTT_NUM_PUBLISHERS=0 \
  -e MQTT_NUM_SUBSCRIBERS=10 \
  -e MQTT_QOS_SUBSCRIBER=1 \
  -e MQTT_SUBSCRIBER_TIMEOUT=60 \
  -e MQTT_EXEC_TIME=120 \
  quay.io/masales/mqttloader:0.8.6
```

### Output Results to File

Save measurement results to CSV files using volume mounts:

```bash
# Create output directory
mkdir -p ./mqtt-results

# Run with output enabled
podman run --rm -it \
  -v ./mqtt-results:/app/output:Z \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  -e MQTT_OUTPUT=/app/output \
  -e MQTT_NUM_PUBLISHERS=5 \
  -e MQTT_NUM_SUBSCRIBERS=5 \
  -e MQTT_NUM_MESSAGES=1000 \
  quay.io/masales/mqttloader:0.8.6

# Results will be saved in ./mqtt-results/mqttloader_YYYYMMDD-HHMMSS.csv
```

### Application Logs

The container uses a customized `logging.properties` configuration that:
- Saves Java logs to `/app/logs/` directory
- Uses both console and file handlers
- Maintains 3 rotating log files (200KB each)
- Formats logs with timestamps and thread information

Mount a volume to access logs:

```bash
# Create logs directory
mkdir -p ./mqtt-logs

# Run with log volume mounted
podman run --rm -it \
  -v ./mqtt-logs:/app/logs:Z \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  quay.io/masales/mqttloader:0.8.6

# Logs will be in ./mqtt-logs/0.log
```

**Logging Configuration:**
- The container overwrites the default `logging.properties` with a customized version from `container/logging.properties`
- FileHandler writes to `/app/logs/%u.log` pattern
- Log level controlled by `MQTT_LOG_LEVEL` environment variable (INFO, WARNING, SEVERE, ALL)

**Custom Logging (Advanced):**
To use your own `logging.properties`, mount it as a volume:

```bash
# Mount custom logging configuration
podman run --rm -it \
  -v ./custom-logging.properties:/app/logging.properties:Z \
  -v ./mqtt-logs:/app/logs:Z \
  -e MQTT_BROKER=192.168.122.49 \
  quay.io/masales/mqttloader:0.8.6
```


### TLS/SSL Configuration

For secure MQTT connections:

```bash
# TLS with custom CA certificate
podman run --rm -it \
  -v ./certs:/app/certs:Z \
  -e MQTT_BROKER=test.mosquitto.org \
  -e MQTT_BROKER_PORT=8883 \
  -e MQTT_TLS=true \
  -e MQTT_TLS_ROOTCA_CERT=/app/certs/ca.crt \
  -e MQTT_NUM_MESSAGES=100 \
  quay.io/masales/mqttloader:0.8.6
```

### Clean Up Local Images

```bash
podman rmi quay.io/masales/mqttloader:0.8.6-amd64
podman rmi quay.io/masales/mqttloader:0.8.6-arm64
podman manifest rm   quay.io/masales/mqttloader:0.8.6
```

## Environment Variables

All available environment variables with their default values:

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MQTT_BROKER` | *(required)* | Broker's IP address or FQDN |
| `MQTT_BROKER_PORT` | `1883` | Broker's port number |
| `MQTT_VERSION` | `5` | MQTT version (3 or 5) |
| `MQTT_NUM_PUBLISHERS` | `1` | Number of publishers |
| `MQTT_NUM_SUBSCRIBERS` | `1` | Number of subscribers |
| `MQTT_QOS_PUBLISHER` | `0` | QoS level for publishers (0/1/2) |
| `MQTT_QOS_SUBSCRIBER` | `0` | QoS level for subscribers (0/1/2) |
| `MQTT_SHARED_SUBSCRIPTION` | `false` | Enable shared subscription |
| `MQTT_RETAIN` | `false` | Enable retained messages |
| `MQTT_TOPIC` | `mqttloader-test-topic` | Topic name |
| `MQTT_PAYLOAD` | `20` | Payload size in bytes (≥8) |
| `MQTT_NUM_MESSAGES` | `100` | Messages per publisher |
| `MQTT_RAMP_UP` | `0` | Ramp-up time in seconds |
| `MQTT_RAMP_DOWN` | `0` | Ramp-down time in seconds |
| `MQTT_INTERVAL` | `0` | Publish interval in microseconds |
| `MQTT_SUBSCRIBER_TIMEOUT` | `5` | Subscriber timeout in seconds |
| `MQTT_EXEC_TIME` | `60` | Max execution time in seconds |
| `MQTT_LOG_LEVEL` | `INFO` | Log level (SEVERE/WARNING/INFO/ALL) |
| `MQTT_NTP` | `es.pool.ntp.org` | NTP server (Madrid, Spain) |
| `MQTT_OUTPUT` | *(none)* | Output directory for CSV results |
| `TZ` | `Europe/Madrid` | Container timezone |
| `MQTT_USER_NAME` | *(none)* | Authentication username |
| `MQTT_PASSWORD` | *(none)* | Authentication password |
| `MQTT_TLS` | *(none)* | Enable TLS (true/false) |
| `MQTT_TLS_ROOTCA_CERT` | *(none)* | Root CA certificate path |
| `MQTT_TLS_CLIENT_KEY` | *(none)* | Client private key path |
| `MQTT_TLS_CLIENT_CERT_CHAIN` | *(none)* | Client certificate chain path |

### Troubleshooting

#### QEMU Setup for Cross-Platform Builds

If building ARM64 on AMD64 (or vice versa), install QEMU:

```bash
# Fedora/RHEL
sudo dnf install qemu-user-static

# Ubuntu/Debian
sudo apt-get install qemu-user-static

# Verify
ls /proc/sys/fs/binfmt_misc/qemu-*
```

#### Common Issues

**Issue**: `manifest unknown` error when removing manifest
**Solution**: This is normal for first-time builds, the error is safely ignored.

**Issue**: ARM64 build fails with "exec format error"  
**Solution**: Ensure QEMU is installed and binfmt_misc is configured.

**Issue**: Gradle crashes during cross-arch build (SIGSEGV in native libraries)  
**Solution**: The script automatically detects this and builds only for native architecture on AMD64 hosts. For true multi-arch, use an ARM64 build host or CI/CD service.

**Issue**: Push fails with authentication error  
**Solution**: Ensure you're logged in: `podman login quay.io`

**Issue**: Manifest inspection shows only one architecture on AMD64 host  
**Solution**: This is expected behavior to avoid Gradle emulation issues. For multi-arch, run from ARM64 host or use CI/CD.

**Issue**: Container doesn't exit or hangs after completion  
**Solution**: The container uses `CMD` instead of `ENTRYPOINT` for fire-and-forget applications. Check logs for exit codes and timestamps.

### Container Debugging

For debugging container execution:

```bash
# Run with verbose logging and volume mounts for logs
podman run --rm -it \
  -v ./logs:/app/logs:Z \
  -v ./results:/app/output:Z \
  -e MQTT_BROKER=192.168.122.49 \
  -e MQTT_USER_NAME=amq-broker \
  -e MQTT_PASSWORD=amq-broker \
  -e MQTT_LOG_LEVEL=ALL \
  -e MQTT_OUTPUT=/app/output \
  quay.io/masales/mqttloader:0.8.6

# Check logs after execution
cat ./logs/0.log
```

**Container lifecycle logging:**
- Timestamps for start/stop events
- Process PID and arguments  
- Exit code capture and reporting
- Signal handling for clean shutdown

### Podman Buildx (Recommended for Multi-Arch)

Podman Buildx is more reliable for cross-platform builds than standard Podman with QEMU emulation:

#### Manual Commands:
```bash
# Remove existing manifest
podman manifest rm quay.io/masales/mqttloader:0.8.6

# Create new manifest
podman manifest create quay.io/masales/mqttloader:0.8.6

# Build multi-arch and add to manifest
podman buildx build --platform linux/amd64,linux/arm64 --no-cache --manifest quay.io/masales/mqttloader:0.8.6 -f container/Containerfile .

# Push manifest
podman manifest push quay.io/masales/mqttloader:0.8.6
```

#### Automated Script:
```bash
# From project root
./container/build-podman-multiarch.sh

# From container/ directory
cd container/
./build-podman-multiarch.sh
```


### Consumer
```shell
podman run --rm -it \
--cpus="4.0" \
--memory="2g" \
-e MQTT_BROKER=192.168.122.49 \
-e MQTT_USER_NAME=amq-broker \
-e MQTT_PASSWORD=amq-broker \
-e MQTT_NUM_PUBLISHERS=0 \
-e MQTT_NUM_SUBSCRIBERS=10 \
-e MQTT_QOS_SUBSCRIBER=1 \
-e MQTT_SUBSCRIBER_TIMEOUT=60 \
-e MQTT_EXEC_TIME=120 \
-e MQTT_TOPIC=load-test-topic \
-v ./sub_output:/app/output:Z \
-e MQTT_OUTPUT=/app/output \
-v ./logs/sub:/app/logs:Z \
quay.io/masales/mqttloader:0.8.6
```

### Publisher
```shell
podman run --rm -it \
--cpus="4.0" \
--memory="2g" \
-e MQTT_BROKER=192.168.122.49 \
-e MQTT_USER_NAME=amq-broker \
-e MQTT_PASSWORD=amq-broker \
-e MQTT_NUM_PUBLISHERS=10 \
-e MQTT_NUM_SUBSCRIBERS=0 \
-e MQTT_NUM_MESSAGES=10000 \
-e MQTT_PAYLOAD=1024 \
-e MQTT_INTERVAL=1000 \
-e MQTT_QOS_PUBLISHER=1 \
-e MQTT_TOPIC=load-test-topic \
-v ./pub_output:/app/output:Z \
-e MQTT_OUTPUT=/app/output \
-v ./logs/pub:/app/logs:Z \
quay.io/masales/mqttloader:0.8.6
```

## Heavy Test

### Consumers
```shell
podman run --rm -it \
--name mqttloader-subscriber \
--cpus="4.0" \
--memory="4g" \
-v ./heavy-test-results:/app/output:Z \
-v ./heavy-test-logs/sub:/app/logs:Z \
--security-opt seccomp=unconfined \
--security-opt apparmor=unconfined \
-e MQTT_BROKER=192.168.122.49 \
-e MQTT_USER_NAME=amq-broker \
-e MQTT_PASSWORD=amq-broker \
-e MQTT_NUM_PUBLISHERS=0 \
-e MQTT_NUM_SUBSCRIBERS=100 \
-e MQTT_QOS_SUBSCRIBER=1 \
-e MQTT_SUBSCRIBER_TIMEOUT=120 \
-e MQTT_EXEC_TIME=350 \
-e MQTT_TOPIC=heavy-load-test \
-e MQTT_OUTPUT=/app/output \
quay.io/masales/mqttloader:0.8.6
```

### Publisher
```shell
podman run --rm -it \
--name mqttloader-publisher \
--cpus="4.0" \
--memory="4g" \
-e MQTT_BROKER=192.168.122.49 \
-v ./heavy-test-logs/pub:/app/logs:Z \
-v ./pub_output:/app/output:Z \
--security-opt seccomp=unconfined \
--security-opt apparmor=unconfined \
-e MQTT_USER_NAME=amq-broker \
-e MQTT_PASSWORD=amq-broker \
-e MQTT_NUM_PUBLISHERS=100 \
-e MQTT_NUM_SUBSCRIBERS=0 \
-e MQTT_NUM_MESSAGES=100000 \
-e MQTT_PAYLOAD=1024 \
-e MQTT_INTERVAL=1000 \
-e MQTT_QOS_PUBLISHER=1 \
-e MQTT_EXEC_TIME=300 \
-e MQTT_TOPIC=heavy-load-test \
-e MQTT_OUTPUT=/app/output \
quay.io/masales/mqttloader:0.8.6
```