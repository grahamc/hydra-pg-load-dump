#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash shellcheck -I nixpkgs=channel:nixos-unstable
# shellcheck shell=bash

set -eux

shellcheck "$0"

readonly src_dataset=rpool/backups/nixos.org/haumea/safe/postgres
readonly working_dataset=rpool/scratch/haumea-load-and-dump

zfs list -t snapshot -H -S createtxg -p -o name "$src_dataset" | head -n1

zfs get all "$working_dataset"
