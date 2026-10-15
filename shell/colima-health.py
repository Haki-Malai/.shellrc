#!/usr/bin/env python3
"""Process cleanup and application-protocol checks for colima-fix."""

import http.client
import json
import os
import signal
import socket
import struct
import subprocess
import sys
import time


# /** Read full command lines belonging to this user.
#  * @returns Mapping of process IDs to command lines.
#  */
def processes():
    output = subprocess.check_output(
        ["ps", "-ww", "-axo", "uid=,pid=,args="], text=True
    )
    return {
        int(pid): args.rstrip()
        for row in output.splitlines()
        for uid, pid, args in [row.strip().split(None, 2)]
        if int(uid) == os.getuid()
    }


# /** Terminate only this profile's SSH masters after its host agent has stopped.
#  * @param home Colima storage directory.
#  * @returns None; raises if shutdown or cleanup is incomplete.
#  */
def cleanup(home):
    instance = os.path.join(os.path.abspath(home), "_lima", "colima")
    master = "ssh: " + instance + "/ssh.sock [mux]"
    snapshot = processes()
    if any("limactl hostagent --pidfile " + instance + "/ha.pid " in args
           for args in snapshot.values()):
        raise RuntimeError("default profile host agent is still running; refusing SSH cleanup")
    for pid, args in snapshot.items():
        if args != master or processes().get(pid) != master:
            continue
        print(f"colima-fix: stopping leftover SSH master {pid}", flush=True)
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 5
    while master in processes().values():
        if time.monotonic() >= deadline:
            raise RuntimeError("leftover SSH masters did not exit; refusing startup")
        time.sleep(0.1)


# /** Require a service response, not merely an accepted TCP connection.
#  * @param host Host bind address.
#  * @param port Published TCP port.
#  * @param service Container port identifying the protocol.
#  * @returns None; raises for timeout or invalid response.
#  */
def probe(host, port, service):
    if service == 4566:
        connection = http.client.HTTPConnection(host, port, timeout=1)
        try:
            connection.request("GET", "/_localstack/health")
            response = connection.getresponse()
            body = json.loads(response.read(1024 * 1024))
            if response.status != 200 or not isinstance(body, dict) or "services" not in body:
                raise RuntimeError("invalid LocalStack health response")
        finally:
            connection.close()
    else:
        with socket.create_connection((host, port), timeout=1) as connection:
            if service == 5432:
                connection.sendall(struct.pack("!II", 8, 80877103))
                if connection.recv(1) not in (b"S", b"N"):
                    raise RuntimeError("invalid PostgreSQL SSL negotiation response")
            else:
                connection.sendall(b"*1\r\n$4\r\nPING\r\n")
                with connection.makefile("rb") as stream:
                    response = stream.readline(4096)
                if response != b"+PONG\r\n" and not response.startswith(b"-NOAUTH "):
                    raise RuntimeError("invalid Valkey/Redis response")


# /** Check supported published services from Docker's running container list.
#  * @param containers Docker GET /containers/json response.
#  * @returns None; raises if any supported forward remains unresponsive.
#  */
def verify(containers):
    if not isinstance(containers, list):
        raise ValueError("invalid Docker container list")
    labels = {5432: "PostgreSQL", 6379: "Valkey/Redis", 4566: "LocalStack"}
    endpoints = set()
    for container in containers:
        for port in container.get("Ports", []):
            service = port.get("PrivatePort")
            if port.get("Type") != "tcp" or "PublicPort" not in port or service not in labels:
                continue
            host = port.get("IP") or "127.0.0.1"
            host = {"0.0.0.0": "127.0.0.1", "::": "::1"}.get(host, host)
            endpoints.add((host, port["PublicPort"], service))
    for host, port, service in sorted(endpoints):
        for attempt in range(5):
            try:
                probe(host, port, service)
                break
            except (OSError, ValueError, RuntimeError, http.client.HTTPException) as error:
                if attempt == 4:
                    raise RuntimeError(f"{labels[service]} forward {host}:{port} failed: {error}") from error
                time.sleep(1)
        print(f"colima-fix: {labels[service]} responds through {host}:{port}", flush=True)
    if not endpoints:
        print("colima-fix: no published PostgreSQL, Valkey/Redis, or LocalStack ports to verify")


if __name__ == "__main__":
    try:
        if sys.argv[1] == "cleanup":
            cleanup(sys.argv[2])
        elif sys.argv[1] == "verify":
            verify(json.load(sys.stdin))
        else:
            raise ValueError("unknown health operation")
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError,
            KeyError, TypeError, AttributeError) as error:
        print(f"colima-fix: {error}", file=sys.stderr)
        sys.exit(1)
