#!/bin/bash

# Directory for alerts
ALERTS_DIR="/home/jjchkconn/alerts"

# Ensure directory exists
mkdir -p "$ALERTS_DIR"

# Create unique filename with timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)
FILENAME="${ALERTS_DIR}/inbound-alerts.${TIMESTAMP}"

# Read email from stdin and save to file
cat > "$FILENAME"

# Set appropriate permissions
chown jjchkconn:jjchkconn "$FILENAME"
chmod 600 "$FILENAME"
