#!/bin/bash
# Container entrypoint: keep the container alive without starting an
# interactive session. tmux and plain shells are started by ./run through
# `podman exec`, so the mode (tmux, plain bash or a one-off command) is
# picked per run instead of being baked into the container's PID 1.
set -e

# `podman stop` / `compose down` send SIGTERM to PID 1, and bash running as
# PID 1 does not react to it on its own - exit cleanly instead.
trap 'exit 0' TERM INT

while true; do
    sleep 3600 &
    wait $! || true
done
