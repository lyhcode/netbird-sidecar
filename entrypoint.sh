#!/bin/bash
set -eEuo pipefail

NB_ENTRYPOINT_SERVICE_TIMEOUT="${NB_ENTRYPOINT_SERVICE_TIMEOUT:-30}"

SERVICE_PIDS=()

on_exit() {
    for pid in "${SERVICE_PIDS[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    wait
    exit 0
}

trap 'on_exit' SIGTERM SIGINT EXIT

wait_for_daemon() {
    local elapsed=0
    echo "Waiting for NetBird daemon..."
    while [ "$elapsed" -lt "$NB_ENTRYPOINT_SERVICE_TIMEOUT" ]; do
        if netbird status --check live >/dev/null 2>&1; then
            echo "NetBird daemon is ready."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "ERROR: NetBird daemon failed to start within ${NB_ENTRYPOINT_SERVICE_TIMEOUT}s"
    exit 1
}

connect() {
    echo "Connecting to NetBird network..."
    netbird up
    echo "Connected: $(netbird status | grep 'NetBird IP' || echo 'IP not yet assigned')"
}

main() {
    netbird service run &
    SERVICE_PIDS+=($!)

    wait_for_daemon
    connect

    echo "NetBird sidecar is running."
    wait "${SERVICE_PIDS[@]}"
}

main
