#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/ssh-setup.sh

#check_hardened() {
#    if ! grep -q "BEGIN BASTION HARDENING" /etc/ssh/sshd_config 2>/dev/null; then
#        echo "ERROR: system has not been hardened yet."
#        echo "Run option 1 (System Hardening) from the admin menu first."
#        exit 1
#    fi
#}
#
#check_hardened

echo "Generating SSH CA..."
mkdir -p /etc/bastion/ca
[ ! -f /etc/bastion/ca/ca_key ] && \
    ssh-keygen -t ed25519 -f /etc/bastion/ca/ca_key -N "" >/dev/null

chown root:bastionca /etc/bastion/ca
chmod 750 /etc/bastion/ca
chown root:bastionca /etc/bastion/ca/ca_key
chmod 640 /etc/bastion/ca/ca_key
chown root:bastionca /etc/bastion/ca/ca_key.pub
chmod 644 /etc/bastion/ca/ca_key.pub

echo "SSH CA setup complete."
sleep 1
