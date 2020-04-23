#!/usr/bin/env nix-shell
#!nix-shell -i bash utillinux -p bash shellcheck -I nixpkgs=channel:nixos-unstable
# shellcheck shell=bash

set -eux
set -o pipefail

shellcheck "$0"

# Required setup:
# sudo zfs create -p rpool/scratch/haumea-load-and-dump
# sudo zfs set mountpoint=/rpool/scratch/haumea-load-and-dump rpool/scratch/haumea-load-and-dump
# sudo zfs allow -dl -u buildkite-agent-pgloadndump create,mount,destroy rpool/scratch/haumea-load-and-dump
# sudo zfs allow -dl -u buildkite-agent-pgloadndump clone,create,mount rpool/backups/nixos.org/haumea/safe/postgres

readonly src_dataset=rpool/backups/nixos.org/haumea/safe/postgres
readonly working_dataset=rpool/scratch/haumea-load-and-dump/target
readonly src_snap=$(zfs list -t snapshot -H -S createtxg -p -o name "$src_dataset" | head -n1)

function finish {
    # a systemd service is watching this path to unmount when the file
    # is changed.
    date > ~/load-n-dump-trigger-unmount
    while mount | grep -q "$working_dataset"; do
        echo "waiting for it to unmount ..."
        sleep 1
    done
    zfs destroy "$working_dataset" || true
}
trap finish EXIT

zfs clone "$src_snap" "$working_dataset"
# a systemd service is watching this path to mount when the file
# is changed.
date > ~/load-n-dump-trigger-mount
while ! mount | grep -q "$working_dataset"; do
    echo "waiting for it to mount ..."
    sleep 1
done
