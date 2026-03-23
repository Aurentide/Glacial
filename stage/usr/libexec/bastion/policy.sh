#!/bin/sh
# aports/scripts/stage/usr/libexec/bastion/policy.sh

POLICY_FILE="/etc/bastion/policy.conf"

# ─── Helpers ─────────────────────────────────────────────────────────────────
list_targets() {
    echo ""
    echo "Current targets:"
    echo ""
    if [ ! -s "$POLICY_FILE" ]; then
        echo "  No targets enrolled yet."
    else
        grep '^\[' "$POLICY_FILE" | tr -d '[]' | while read -r t; do
            allowed=$(awk -v t="[$t]" '
                $0==t{f=1;next} f&&/^\[/{f=0} f&&$1=="allowed_users"{print $3}
            ' "$POLICY_FILE")
            user=$(awk -v t="[$t]" '
                $0==t{f=1;next} f&&/^\[/{f=0} f&&$1=="target_user"{print $3}
            ' "$POLICY_FILE")
            ttl=$(awk -v t="[$t]" '
                $0==t{f=1;next} f&&/^\[/{f=0} f&&$1=="ttl"{print $3}
            ' "$POLICY_FILE")
            echo "  [$t]"
            echo "    target_user:   $user"
            echo "    allowed_users: $allowed"
            echo "    ttl:           $ttl"
            echo ""
        done
    fi
}

remove_target() {
    local target="$1"
    awk -v t="[$target]" '
        $0==t{skip=1;next}
        skip&&/^\[/{skip=0}
        skip{next}
        {print}
    ' "$POLICY_FILE" > /tmp/policy.tmp && mv /tmp/policy.tmp "$POLICY_FILE"
}

# ─── Main Menu ────────────────────────────────────────────────────────────────
while true; do
    clear
    echo "=== Policy Configuration ==="
    list_targets

    echo "Options:"
    echo "  1) Add target"
    echo "  2) Remove target"
    echo "  3) Edit target"
    echo "  4) Back"
    echo ""
    read -r -p "Select option: " choice

    case "$choice" in
        1)
            echo ""
            read -r -p "Target hostname or IP: " TARGET
            [ -z "$TARGET" ] && { echo "Aborted."; sleep 1; continue; }

            if grep -q "^\[$TARGET\]" "$POLICY_FILE" 2>/dev/null; then
                echo "ERROR: '$TARGET' already exists. Use Edit to modify it."
                sleep 2; continue
            fi

            read -r -p "Target user: " TARGET_USER
            read -r -p "Allowed users (comma-separated): " ALLOWED
            read -r -p "TTL [default: 5m]: " TTL
            TTL="${TTL:-5m}"

            cat >> "$POLICY_FILE" <<EOF

[$TARGET]
allowed_users = $ALLOWED
target_user = $TARGET_USER
ttl = $TTL
EOF
            echo "Target '$TARGET' added."
            sleep 1
            ;;

        2)
            echo ""
            read -r -p "Target to remove: " TARGET
            [ -z "$TARGET" ] && { echo "Aborted."; sleep 1; continue; }

            if ! grep -q "^\[$TARGET\]" "$POLICY_FILE" 2>/dev/null; then
                echo "ERROR: '$TARGET' not found in policy.conf"
                sleep 2; continue
            fi

            read -r -p "Remove '$TARGET'? [y/N]: " CONFIRM
            case "$CONFIRM" in
                y|Y)
                    remove_target "$TARGET"
                    echo "Target '$TARGET' removed."
                    sleep 1
                    ;;
                *)
                    echo "Aborted."
                    sleep 1
                    ;;
            esac
            ;;

        3)
            echo ""
            read -r -p "Target to edit: " TARGET
            [ -z "$TARGET" ] && { echo "Aborted."; sleep 1; continue; }

            if ! grep -q "^\[$TARGET\]" "$POLICY_FILE" 2>/dev/null; then
                echo "ERROR: '$TARGET' not found in policy.conf"
                sleep 2; continue
            fi

            CUR_USER=$(awk -v t="[$TARGET]" '
                $0==t{f=1;next} f&&/^\[/{f=0} f&&$1=="target_user"{print $3}
            ' "$POLICY_FILE")
            CUR_ALLOWED=$(awk -v t="[$TARGET]" '
                $0==t{f=1;next} f&&/^\[/{f=0} f&&$1=="allowed_users"{print $3}
            ' "$POLICY_FILE")
            CUR_TTL=$(awk -v t="[$TARGET]" '
                $0==t{f=1;next} f&&/^\[/{f=0} f&&$1=="ttl"{print $3}
            ' "$POLICY_FILE")

            echo "Leave blank to keep current value."
            echo ""
            read -r -p "Target user [$CUR_USER]: " NEW_USER
            read -r -p "Allowed users [$CUR_ALLOWED]: " NEW_ALLOWED
            read -r -p "TTL [$CUR_TTL]: " NEW_TTL

            NEW_USER="${NEW_USER:-$CUR_USER}"
            NEW_ALLOWED="${NEW_ALLOWED:-$CUR_ALLOWED}"
            NEW_TTL="${NEW_TTL:-$CUR_TTL}"

            remove_target "$TARGET"

            cat >> "$POLICY_FILE" <<EOF

[$TARGET]
allowed_users = $NEW_ALLOWED
target_user = $NEW_USER
ttl = $NEW_TTL
EOF
            echo "Target '$TARGET' updated."
            sleep 1
            ;;

        4)
            break
            ;;

        *)
            echo "Invalid choice."
            sleep 1
            ;;
    esac
done
