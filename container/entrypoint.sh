#!/bin/bash
set -e

# Configure system limits for high-concurrency workloads
echo "[$(date)] Current limits before changes:"
ulimit -a

# Try to set limits with detailed feedback
echo "[$(date)] Setting file descriptor limit to 65536..."
ulimit -n 65536 && echo "[$(date)] ✓ File descriptor limit set" || echo "[$(date)] ✗ Failed to set file descriptor limit"

echo "[$(date)] Setting process limit to 32768..."
ulimit -u 32768 && echo "[$(date)] ✓ Process limit set" || echo "[$(date)] ✗ Failed to set process limit"

echo "[$(date)] Final limits:"
ulimit -a

# Also check system-wide limits
echo "[$(date)] System info:"
echo "  threads-max: $(cat /proc/sys/kernel/threads-max 2>/dev/null || echo 'N/A')"
echo "  pid_max: $(cat /proc/sys/kernel/pid_max 2>/dev/null || echo 'N/A')"
echo "  max_map_count: $(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 'N/A')"
echo "  available memory: $(cat /proc/meminfo | grep MemAvailable || echo 'N/A')"

# Set JVM options to help with thread management
export JAVA_OPTS="$JAVA_OPTS -XX:+UseLargePages -XX:+UseTransparentHugePages -Djava.security.egd=file:/dev/./urandom"
echo "[$(date)] JAVA_OPTS: $JAVA_OPTS"
echo "[$(date)] MQTTLOADER_OPTS: $MQTTLOADER_OPTS"

# Trap for cleanup and logging
trap 'echo "[$(date)] MQTTLoader process interrupted or terminated"; exit 143' TERM INT

echo "[$(date)] Generating configuration from environment variables..."
./generate-config.sh

echo "[$(date)] Starting MQTTLoader..."
echo "[$(date)] Process PID: $$"
echo "[$(date)] Arguments: $*"

# Execute MQTTLoader and capture exit code
mqttloader "$@"
EXIT_CODE=$?

echo "[$(date)] MQTTLoader finished with exit code: $EXIT_CODE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] MQTTLoader completed successfully"
else
    echo "[$(date)] MQTTLoader failed with error code $EXIT_CODE" >&2
fi

exit $EXIT_CODE
