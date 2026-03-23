#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/keyctl.sh

CMD="$1"
SESSION_ID="$2"
TARGET_USER="$3"
TTL="${4:-5m}"
SESSION_DIR="/run/bastion/sessions/$SESSION_ID"
CA_KEY="/etc/bastion/ca/ca_key"

case "$CMD" in
    generate)
        [ -z "$SESSION_ID" ] && { echo "ERROR: no session ID provided";  exit 1; }
        [ -z "$TARGET_USER" ] && { echo "ERROR: no target user provided"; exit 1; }
        [ ! -f "$CA_KEY" ] && { echo "ERROR: run SSH CA Initialization first"; exit 1; }

        mkdir -p "$SESSION_DIR"

        ssh-keygen -t ed25519 -f "$SESSION_DIR/ephemeral" -N "" >/dev/null

        ssh-keygen -s "$CA_KEY" \
                   -I "bastion-session-$SESSION_ID" \
                   -n "$TARGET_USER" \
                   -V "+${TTL}" \
                   -O no-x11-forwarding \
                   -O no-agent-forwarding \
                   -O no-port-forwarding \
                   "$SESSION_DIR/ephemeral.pub" >/dev/null

        echo "$SESSION_DIR/ephemeral-cert.pub"
        ;;

    destroy)
        [ -z "$SESSION_ID" ] && { echo "ERROR: no session ID provided"; exit 1; }
        rm -rf "$SESSION_DIR"
        ;;

    "")
        echo "Key Control"
        echo "CA key present: $([ -f "$CA_KEY" ] && echo "YES" || echo "NO, run SSH CA Initialization")"
        echo ""
        echo "Active sessions:"
        ls /run/bastion/sessions/ 2>/dev/null || echo "  None"
        ;;

    *)
        echo "Usage: keyctl.sh {generate|destroy} <session_id> [target_user] [ttl]"
        exit 1
        ;;
esac
