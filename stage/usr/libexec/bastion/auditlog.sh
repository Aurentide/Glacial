#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/auditlog.sh

LOG_DIR="/etc/bastion/logs"

echo "=== Audit Logs ==="
echo ""

if [ -z "$(ls -A $LOG_DIR 2>/dev/null)" ]; then
    echo "No session logs found."
    exit 0
fi

echo "Available sessions:"
echo ""
ls -lt "$LOG_DIR" | grep -v '^total' | awk '{print NR")", $9, $6, $7, $8}'
echo ""
read -r -p "Enter session number to view (or press enter to exit): " choice

[ -z "$choice" ] && exit 0

LOG_FILE=$(ls -lt "$LOG_DIR" | grep -v '^total' | awk -v n="$choice" 'NR==n{print $9}')

[ -z "$LOG_FILE" ] && { echo "Invalid selection."; exit 1; }

echo ""
cat "$LOG_DIR/$LOG_FILE"
