#!/bin/sh -e
# glacial-bastion/build/genapkovl-bastion.sh

HOSTNAME="bastion"

cleanup() {
    rm -rf "$tmp"
}

makefile() {
    OWNER="$1"
    PERMS="$2"
    FILENAME="$3"
    cat > "$FILENAME"
    chown "$OWNER" "$FILENAME"
    chmod "$PERMS" "$FILENAME"
}

rc_add() {
    mkdir -p "$tmp"/etc/runlevels/"$2"
    ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup exit

mkdir -p "$tmp"/etc
mkdir -p "$tmp"/etc/apk
mkdir -p "$tmp"/etc/init.d
mkdir -p "$tmp"/etc/local.d
mkdir -p "$tmp"/etc/network

cp ../scripts/setup-firstboot "$tmp"/etc/init.d/setup-firstboot
cp ../scripts/run-installer "$tmp"/etc/run-installer
chmod 755 "$tmp"/etc/run-installer
cp ../scripts/bastion-setup.start "$tmp"/etc/local.d/bastion-setup.start
cp ../scripts/bastion-runtime.start "$tmp"/etc/local.d/bastion-runtime.start
chmod 755 "$tmp"/etc/local.d/bastion-runtime.start
cp -a ../stage/* "$tmp"/etc

makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
alpine-base
EOF

makefile root:root 0755 "$tmp"/etc/inittab <<EOF
# /etc/inittab

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

tty1::once:/etc/run-installer

tty2::respawn:/sbin/getty 38400 tty2

::shutdown:/sbin/openrc shutdown
EOF

makefile root:root 0644 "$tmp"/etc/motd <<EOF
Welcome to Glacial Bastion
EOF

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add setup-firstboot default
rc_add local default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
