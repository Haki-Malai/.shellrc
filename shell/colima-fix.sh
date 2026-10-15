#!/usr/bin/env bash

if [ "$#" -eq 1 ] && [ "$1" = "--help" ]; then
  printf 'Usage: colima-fix [--help]\nRecover the default Colima profile: stop, force-stop, clean leftover SSH masters, start, then check Docker and published PostgreSQL/Valkey/LocalStack responses.\n'
  exit 0
fi
if [ "$#" -ne 0 ]; then
  printf 'colima-fix: unsupported arguments; use --help\n' >&2
  exit 2
fi

trap 'exit 130' INT
trap 'exit 143' TERM
for dependency in colima curl jq nc ps; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'colima-fix: required command not found: %s\n' "$dependency" >&2
    exit 127
  fi
done

colima_home="${COLIMA_HOME:-$HOME/.colima}"
health_helper="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/colima-health.sh"
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
printf 'colima-fix: cleaning leftover default-profile SSH masters\n'
bash "$health_helper" cleanup "$colima_home" || exit 1
printf 'colima-fix: starting default profile\n'
colima --profile default start
start_status=$?
[ "$start_status" -eq 0 ] || exit "$start_status"

response=''
docker_healthy=0
for attempt in 1 2 3 4 5; do
  if response="$(curl --noproxy '*' --silent --show-error --fail --max-time 1 --unix-socket "$colima_home/default/docker.sock" http://localhost/_ping)" && [ "$response" = OK ]; then
    docker_healthy=1
    break
  fi
  [ "$attempt" -eq 5 ] || sleep 1
done
if [ "$docker_healthy" -ne 1 ]; then
  printf 'colima-fix: startup completed but Docker health check failed\n' >&2
  exit 1
fi
if ! containers="$(curl --noproxy '*' --silent --show-error --fail --max-time 3 --unix-socket "$colima_home/default/docker.sock" http://localhost/containers/json)"; then
  printf 'colima-fix: cannot inspect published container ports\n' >&2
  exit 1
fi
printf '%s\n' "$containers" | bash "$health_helper" verify || exit 1
printf 'colima-fix: default profile recovered; Docker is responding; supported published service checks passed\n'
