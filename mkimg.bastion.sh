#!/bin/sh
# aports/scripts/mkimg.bastion.sh
profile_bastion() {
    profile_virt
    profile_abbrev="bastion"
    title="bastion"
    arch="x86_64 x86"
    apks="$apks syslinux"

    local _k _a
    for _k in $kernel_flavors; do
        apks="$apks linux-$_k"
        for _a in $kernel_addons; do
            apks="$apks $_a-$_k"
        done
    done

    apks="$apks linux-firmware linux-firmware-none util-linux"
    apkovl="genapkovl-bastion.sh"
}
