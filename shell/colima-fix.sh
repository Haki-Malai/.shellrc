#!/usr/bin/env bash

if [ "$#" -eq 1 ] && [ "$1" = "--help" ]; then
  printf 'Usage: colima-fix [--help]\nRecover the default Colima profile: stop, force-stop, start, then check Docker.\n'
  exit 0
fi
if [ "$#" -ne 0 ]; then
  printf 'colima-fix: unsupported arguments; use --help\n' >&2
  exit 2
fi

trap 'exit 130' INT
trap 'exit 143' TERM
for dependency in colima curl; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'colima-fix: required command not found: %s\n' "$dependency" >&2
    exit 127
  fi
done

colima_home="${COLIMA_HOME:-$HOME/.colima}"
if [ ! -r "$colima_home/default/colima.yaml" ]; then
  printf 'colima-fix: default profile storage/configuration unavailable: %s\n' "$colima_home/default/colima.yaml" >&2
  exit 1
fi

printf 'colima-fix: stopping default profile\n'
colima --profile default stop || printf 'colima-fix: stop failed; continuing recovery\n' >&2
printf 'colima-fix: force-stopping default profile\n'
colima --profile default stop --force || printf 'colima-fix: force-stop failed; continuing recovery\n' >&2
if [ ! -r "$colima_home/default/colima.yaml" ]; then
  printf 'colima-fix: default profile storage/configuration unavailable before startup: %s\n' "$colima_home/default/colima.yaml" >&2
  exit 1
fi
printf 'colima-fix: starting default profile\n'
colima --profile default start
start_status=$?
[ "$start_status" -eq 0 ] || exit "$start_status"

if response="$(curl --silent --show-error --fail --max-time 1 --unix-socket "$colima_home/default/docker.sock" http://localhost/_ping)" && [ "$response" = OK ]; then
  printf 'colima-fix: default profile recovered; Docker is responding\n'
else
  printf 'colima-fix: startup completed but Docker health check failed\n' >&2
  exit 1
fi
