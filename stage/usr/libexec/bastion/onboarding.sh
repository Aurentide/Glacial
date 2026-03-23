#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/onboarding.sh

check_hardened() {
    if ! grep -q "BEGIN BASTION HARDENING" /etc/ssh/sshd_config 2>/dev/null; then
        echo "ERROR: system has not been hardened yet."
        echo "Run option 1 (System Hardening) from the admin menu first."
        exit 1
    fi
}

check_hardened

CA_PUB="/etc/bastion/ca/ca_key.pub"
POLICY_FILE="/etc/bastion/policy.conf"

echo "=== Target Enrollment ==="
echo ""

#Preflight
[ ! -f "$CA_PUB" ] && {
    echo "ERROR: CA public key not found at $CA_PUB"
    echo "Run SSH CA Initialization first."
    exit 1
}

#Collect Target Details
printf "Target hostname or IP: "
read -r TARGET
[ -z "$TARGET" ] && { echo "ERROR: target cannot be empty"; exit 1; }

printf "Target user (the account broker will connect as): "
read -r TARGET_USER
[ -z "$TARGET_USER" ] && { echo "ERROR: target user cannot be empty"; exit 1; }

printf "Allowed bastion users (comma-separated, e.g. alice,bob): "
read -r ALLOWED_USERS
[ -z "$ALLOWED_USERS" ] && { echo "ERROR: allowed users cannot be empty"; exit 1; }

printf "Session TTL (e.g. 5m, 1h) [default: 5m]: "
read -r TTL
TTL="${TTL:-5m}"

printf "Admin user on target for bootstrapping (will not be stored): "
read -r ADMIN_USER
[ -z "$ADMIN_USER" ] && { echo "ERROR: admin user cannot be empty"; exit 1; }

#Check for existing policy entry
if grep -q "^\[$TARGET\]" "$POLICY_FILE" 2>/dev/null; then
    printf "WARNING: '$TARGET' already exists in policy.conf. Overwrite? [y/N]: "
    read -r CONFIRM
    case "$CONFIRM" in
        y|Y) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

#Deploy CA Public Key to Target
echo ""
echo "Deploying CA public key to $TARGET..."
echo "You will be prompted for $ADMIN_USER's password on $TARGET."
echo ""

scp -o StrictHostKeyChecking=accept-new \
    -o PasswordAuthentication=yes \
    "$CA_PUB" "$ADMIN_USER@$TARGET:/tmp/bastion_ca.pub" \
    || { echo "ERROR: failed to copy CA public key to $TARGET"; exit 1; }

echo "CA public key copied to target."

#Configure sshd on Target
echo "Configuring sshd on $TARGET..."

ssh -t -o PasswordAuthentication=yes \
    "$ADMIN_USER@$TARGET" "
    if command -v doas >/dev/null 2>&1; then PRIV=doas
    elif command -v sudo >/dev/null 2>&1; then PRIV=sudo
    else echo 'ERROR: no privilege escalation tool found'; exit 1
    fi

    \$PRIV mv /tmp/bastion_ca.pub /etc/ssh/bastion_ca.pub
    \$PRIV chmod 644 /etc/ssh/bastion_ca.pub

    if ! \$PRIV grep -q 'TrustedUserCAKeys' /etc/ssh/sshd_config; then
        echo 'TrustedUserCAKeys /etc/ssh/bastion_ca.pub' \
            | \$PRIV tee -a /etc/ssh/sshd_config > /dev/null
        echo 'sshd_config updated.'
    else
        echo 'TrustedUserCAKeys already present — skipping.'
    fi

    if ! id '$TARGET_USER' >/dev/null 2>&1; then
        echo 'ERROR: user $TARGET_USER does not exist on target — create it first.'
        exit 1
    fi
    echo 'Target user $TARGET_USER verified.'

    if command -v rc-service >/dev/null 2>&1; then
        \$PRIV rc-service sshd restart && echo 'sshd restarted.'
    elif command -v systemctl >/dev/null 2>&1; then
        \$PRIV systemctl restart sshd && echo 'sshd restarted.'
    else
        echo 'WARNING: could not restart sshd — restart manually.'
    fi
" || { echo "ERROR: remote configuration failed on $TARGET"; exit 1; }

#Write Policy Entry
echo ""
echo "Writing policy entry..."

if grep -q "^\[$TARGET\]" "$POLICY_FILE" 2>/dev/null; then
    awk -v t="[$TARGET]" '
        $0 == t { skip=1; next }
        skip && /^\[/ { skip=0 }
        skip { next }
        { print }
    ' "$POLICY_FILE" > /tmp/policy.tmp && mv /tmp/policy.tmp "$POLICY_FILE"
fi

cat >> "$POLICY_FILE" <<EOF

[$TARGET]
allowed_users = $ALLOWED_USERS
target_user = $TARGET_USER
ttl = $TTL
EOF

echo "Policy entry written for $TARGET."

#Summary
echo ""
echo "=== Enrollment complete ==="
echo "  Target:        $TARGET"
echo "  Target user:   $TARGET_USER"
echo "  Allowed users: $ALLOWED_USERS"
echo "  TTL:           $TTL"
