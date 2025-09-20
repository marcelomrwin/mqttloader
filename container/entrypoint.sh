#!/bin/bash
set -e

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
