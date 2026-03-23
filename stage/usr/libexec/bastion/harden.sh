#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/finalize.sh
echo "Sealing onboarding..."
echo "onboarding_complete=1" > /var/lib/bastion/state
sleep 1
echo "System is operational for regular users."
localhost:~/aports/scripts/stage/usr/libexec/bastion$ cat harden.sh
#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/harden.sh

SSHD_CONFIG="/etc/ssh/sshd_config"
BASTION_BLOCK="# BEGIN BASTION HARDENING"
BASTION_BLOCK_END="# END BASTION HARDENING"

echo "=== System Hardening ==="
echo ""

[ ! -f "$SSHD_CONFIG" ] && { echo "ERROR: sshd_config not found at $SSHD_CONFIG"; exit 1; }

# Ensure bastionca group exists
addgroup -S bastionca 2>/dev/null || true
log_group=$(grep -c "^bastionca" /etc/group 2>/dev/null)
[ "$log_group" -gt 0 ] && echo "  bastionca group present." || echo "  WARNING: bastionca group could not be created."

# Filesystem Permissions
echo ""
echo "Setting permissions on sensitive directories..."

chown root:bastionca /etc/bastion/ca
chmod 750 /etc/bastion/ca             && echo "  /etc/bastion/ca          → 750 (root:bastionca)"

chown root:root /etc/bastion/keys
chmod 700 /etc/bastion/keys           && echo "  /etc/bastion/keys        → 700 (root:root)"

chown root:bastionca /etc/bastion/logs
chmod 770 /etc/bastion/logs           && echo "  /etc/bastion/logs        → 770 (root:bastionca)"

chown root:bastionca /etc/bastion/ca/ca_key 2>/dev/null || true
chmod 640 /etc/bastion/ca/ca_key 2>/dev/null \
    && echo "  /etc/bastion/ca/ca_key   → 640 (root:bastionca)" \
    || echo "  /etc/bastion/ca/ca_key not present yet — set permissions after CA init."

chown root:bastionca /etc/bastion/ca/ca_key.pub 2>/dev/null || true
chmod 644 /etc/bastion/ca/ca_key.pub 2>/dev/null \
    && echo "  /etc/bastion/ca/ca_key.pub → 644 (root:bastionca)" \
    || echo "  /etc/bastion/ca/ca_key.pub not present yet — set permissions after CA init."

# SSH Hardening
echo ""
echo "Hardening sshd_config..."

if grep -q "$BASTION_BLOCK" "$SSHD_CONFIG"; then
    echo "  Bastion hardening block already present — skipping."
else
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak" \
        && echo "  Backup written to ${SSHD_CONFIG}.bak"

    MATCH_LINE=$(grep -n '^Match ' "$SSHD_CONFIG" | head -1 | cut -d: -f1)

    HARDENING_BLOCK="
$BASTION_BLOCK
# Applied by harden.sh — do not edit this block manually.

PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
LogLevel VERBOSE
SyslogFacility AUTH
LoginGraceTime 30
MaxAuthTries 3

$BASTION_BLOCK_END"

    if [ -n "$MATCH_LINE" ]; then
        before=$((MATCH_LINE - 1))
        head -n "$before" "$SSHD_CONFIG" > /tmp/sshd_config.tmp
        echo "$HARDENING_BLOCK" >> /tmp/sshd_config.tmp
        tail -n "+${MATCH_LINE}" "$SSHD_CONFIG" >> /tmp/sshd_config.tmp
        mv /tmp/sshd_config.tmp "$SSHD_CONFIG"
        echo "  Hardening block inserted before Match blocks."
    else
        echo "$HARDENING_BLOCK" >> "$SSHD_CONFIG"
        echo "  Hardening block appended."
    fi
fi

# Sysctl Hardening
echo ""
echo "Applying sysctl hardening..."

cat > /etc/sysctl.d/99-bastion.conf <<EOF
# Bastion hardening — applied by harden.sh
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOF

sysctl -p /etc/sysctl.d/99-bastion.conf >/dev/null 2>&1 \
    && echo "  sysctl rules applied." \
    || echo "  WARNING: sysctl apply failed — rules will take effect on next boot."

# Restart sshd
echo ""
echo "Restarting sshd..."
rc-service sshd restart \
    && echo "  sshd restarted successfully." \
    || { echo "  ERROR: sshd failed to restart — check sshd_config syntax."; exit 1; }

echo ""
echo "=== Hardening complete ==="
