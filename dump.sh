#!/usr/bin/env nix-shell
#!nix-shell -i bash utillinux -p bash shellcheck postgresql_11 -I nixpkgs=channel:nixos-unstable
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
readonly working_dir=/$working_dataset
readonly src_snap=$(zfs list -t snapshot -H -S createtxg -p -o name "$src_dataset" | head -n1)
readonly socket=$(mktemp -d -t tmp.XXXXXXXXXX)

function finish {
    set +e
    pg_ctl -D "$working_dir" \
           -o "-F -h '' -k \"$socket\"" \
           -w stop -m immediate

    if [ -f "$working_dir/postmaster.pid" ]; then
        pg_ctl -D "$working_dir" \
               -o "-F -h '' -k \"$socket\"" \
               -w kill TERM "$(cat "$working_dir/postmaster.pid")"
    fi

    # a systemd service is watching this path to unmount when the file
    # is changed.
    while mount | grep -q "$working_dataset"; do
        date > ~/load-n-dump-trigger-unmount
        echo "waiting for it to unmount ..."
        sleep 1
    done
    while zfs get name "$working_dataset"; do
        zfs destroy "$working_dataset"
        sleep 1
    done
    rm -rf "$socket"
}
trap finish EXIT

if zfs get name "$working_dataset"; then
    echo "target already exists, aborting"
    exit 1
fi

zfs clone -o canmount=noauto "$src_snap" "$working_dataset"
if ! zfs get name "$working_dataset"; then
    echo "target does not exist, aborting"
    exit 1
fi

# a systemd service is watching this path to mount when the file
# is changed.
date > ~/load-n-dump-trigger-mount
while ! mount | grep -q "$working_dataset"; do
    echo "waiting for it to mount ..."
    sleep 1
done

echo "janky sleep waiting for a chown to finish ..."
sleep 30

rm "$working_dir/postgresql.conf"
cat <<EOF > "$working_dir/postgresql.conf"
max_connections = 100
shared_buffers = 128MB
min_wal_size = 80MB
max_wal_size = 1GB
lc_time = 'en_US.UTF-8'				# locale for time formatting
lc_numeric = 'en_US.UTF-8'			# locale for number formatting
lc_monetary = 'en_US.UTF-8'			# locale for monetary formatting
lc_messages = 'en_US.UTF-8'			# locale for system error message
log_timezone = 'UTC'
dynamic_shared_memory_type = posix
default_text_search_config = 'pg_catalog.english'
datestyle = 'iso, mdy'
EOF

pg_ctl -D "$working_dir" \
       -o "-F -h '' -k \"${socket}\"" \
       --timeout 86400 \
       -w start

pg_dump hydra \
        --create --format=directory --exclude-table users --verbose \
        -U hydra --host "$socket" -f ./dump
