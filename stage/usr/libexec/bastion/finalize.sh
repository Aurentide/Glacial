#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/finalize.sh
echo "Sealing onboarding..."
echo "onboarding_complete=1" > /var/lib/bastion/state
sleep 1
echo "System is operational for regular users."
