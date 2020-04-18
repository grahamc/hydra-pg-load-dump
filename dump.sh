#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash shellcheck -I nixpkgs=channel:nixos-unstable
# shellcheck shell=bash

set -eux
set -o pipefail

shellcheck "$0"

readonly src_dataset=rpool/backups/nixos.org/haumea/safe/postgres
readonly working_dataset=rpool/scratch/haumea-load-and-dump/target
readonly src_snap=$(zfs list -t snapshot -H -S createtxg -p -o name "$src_dataset" | head -n1)

function finish {
    zfs destroy "$working_dataset" || true
}
trap finish EXIT

zfs clone "$src_snap" "$working_dataset"
