#!/usr/bin/env bash
# Process cleanup and application-protocol checks for colima-fix.

# /** List this user's SSH masters, refusing cleanup while the host agent runs.
#  * @param $1 Absolute Lima instance directory.
#  * @returns Matching process IDs on stdout; nonzero if inspection fails.
#  */
colima_health_masters() {
  local instance="$1" snapshot proc_uid pid args
  snapshot="$(ps -ww -axo uid=,pid=,args=)" || return 1
  while read -r proc_uid pid args; do
    [ "$proc_uid" = "$UID" ] || continue
    case "$args" in
      *"limactl hostagent --pidfile $instance/ha.pid "*)
        printf 'colima-fix: default profile host agent is still running; refusing SSH cleanup\n' >&2
        return 1 ;;
    esac
    [ "$args" != "ssh: $instance/ssh.sock [mux]" ] || printf '%s\n' "$pid"
  done <<<"$snapshot"
}

# /** Terminate only this profile's SSH masters after its host agent has stopped.
#  * @param $1 Colima storage directory.
#  * @returns Nonzero if shutdown, inspection, or cleanup is incomplete.
#  */
colima_health_cleanup() {
  local instance masters current pid attempt
  instance="$(cd -- "$1" && pwd -L)/_lima/colima" || return 1
  masters="$(colima_health_masters "$instance")" || return 1
  while read -r pid; do
    [ -n "$pid" ] || continue
    current="$(colima_health_masters "$instance")" || return 1
    # Recheck identity immediately before signaling; a reused PID must be skipped.
    case $'\n'"$current"$'\n' in
      *$'\n'"$pid"$'\n'*)
        printf 'colima-fix: stopping leftover SSH master %s\n' "$pid"
        if ! kill -TERM "$pid" 2>/dev/null; then
          current="$(colima_health_masters "$instance")" || return 1
          case $'\n'"$current"$'\n' in *$'\n'"$pid"$'\n'*) return 1 ;; esac
        fi ;;
    esac
  done <<<"$masters"
  for ((attempt=0; attempt<=50; attempt++)); do
    current="$(colima_health_masters "$instance")" || return 1
    [ -n "$current" ] || return 0
    [ "$attempt" -eq 50 ] || sleep 0.1
  done
  printf 'colima-fix: leftover SSH masters did not exit; refusing startup\n' >&2
  return 1
}

# /** Require a service response, not merely an accepted TCP connection.
#  * @param $1 Host bind address.
#  * @param $2 Published TCP port.
#  * @param $3 Container port identifying the protocol.
#  * @returns Success only for an expected protocol response.
#  */
colima_health_probe() {
  local host="$1" port="$2" service="$3" response
  case "$service" in
    5432)
      # Keep stdin open for the response window: macOS nc exits on stdin EOF.
      response="$({ printf '\000\000\000\010\004\322\026\057'; sleep 1; } | nc -w 1 "$host" "$port" 2>/dev/null)" || return 1
      [ "$response" = S ] || [ "$response" = N ] ;;
    6379)
      response="$({ printf '*1\r\n$4\r\nPING\r\n'; sleep 1; } | nc -w 1 "$host" "$port" 2>/dev/null)" || return 1
      case "$response" in $'+PONG\r'|'-NOAUTH '*$'\r') return 0 ;; *) return 1 ;; esac ;;
    4566)
      case "$host" in *:*) host="[$host]" ;; esac
      response="$(curl --noproxy '*' --silent --fail --max-time 1 --write-out $'\n%{http_code}' "http://$host:$port/_localstack/health")" || return 1
      [ "${response##*$'\n'}" = 200 ] || return 1
      printf '%s\n' "${response%$'\n'*}" | jq -e 'type == "object" and has("services")' >/dev/null ;;
    *) return 1 ;;
  esac
}

# /** Check supported published services from Docker's running container list.
#  * @returns Nonzero for invalid stdin JSON or any unresponsive supported forward.
#  */
colima_health_verify() {
  local endpoints host port service label attempt
  endpoints="$(jq -sr '
    if length != 1 then error("expected one Docker container list") else .[0] end |
    if type != "array" then error("invalid Docker container list") else . end |
    [.[] | .Ports[]? |
      select(.Type == "tcp" and .PublicPort != null and
        (.PrivatePort == 5432 or .PrivatePort == 6379 or .PrivatePort == 4566)) |
      [((.IP // "127.0.0.1") | if . == "0.0.0.0" or . == "" then "127.0.0.1" elif . == "::" then "::1" else . end),
       .PublicPort, .PrivatePort]] | unique[] | @tsv
  ')" || return 1
  if [ -z "$endpoints" ]; then
    printf 'colima-fix: no published PostgreSQL, Valkey/Redis, or LocalStack ports to verify\n'
    return 0
  fi
  while IFS=$'\t' read -r host port service; do
    case "$service" in 5432) label=PostgreSQL ;; 6379) label=Valkey/Redis ;; 4566) label=LocalStack ;; esac
    for attempt in 1 2 3 4 5; do
      if colima_health_probe "$host" "$port" "$service"; then break; fi
      if [ "$attempt" -eq 5 ]; then
        printf 'colima-fix: %s forward %s:%s failed: no valid protocol response\n' "$label" "$host" "$port" >&2
        return 1
      fi
      sleep 1
    done
    printf 'colima-fix: %s responds through %s:%s\n' "$label" "$host" "$port"
  done <<<"$endpoints"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1-}" in
    cleanup) colima_health_cleanup "$2" ;;
    verify) colima_health_verify ;;
    *) printf 'colima-fix: unknown health operation\n' >&2; exit 2 ;;
  esac
fi
