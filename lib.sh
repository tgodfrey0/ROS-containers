#!/bin/bash
# Shared helpers for the ROS 2 container scripts (sourced, never executed).
#
# The container itself is defined in ./compose.yaml; this file only picks the
# container engine (podman preferred, docker as fallback), validates the
# distro argument, prepares X11/GUI forwarding and provides listing helpers.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$SCRIPT_DIR"

# Distros the Containerfile knows how to install Gazebo Sim for.
SUPPORTED_DISTROS=(humble iron jazzy kilted rolling)

DISTROS_FILE="./available_distros"

die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# compose.yaml always needs an Xauthority path, even for build/remove.
#
# $XAUTHORITY is usually a login-manager temp file (SDDM: /tmp/xauth_XXXXXX),
# and /tmp/xauth_* is wiped at boot (see /usr/lib/tmpfiles.d/sddm.conf).
# Mounting that path directly bakes it into the container's configuration, so
# after a reboot podman can no longer start the container:
#
#     crun: cannot stat `/tmp/xauth_XXXXXX`: No such file or directory
#
# Keep a stable copy under $HOME (which is already mounted into the container)
# and point compose at that instead. The copy is refreshed on every run, so a
# long-running container keeps working across host logins too.
STABLE_XAUTHORITY="$HOME/.cache/ros2-containers/Xauthority"

prepare_xauthority() {
    local source="${XAUTHORITY:-}"

    mkdir -p -- "$(dirname -- "$STABLE_XAUTHORITY")" 2>/dev/null || true
    if [[ -n "$source" && -f "$source" && "$source" != "$STABLE_XAUTHORITY" ]]; then
        # In-place write (not `cp`): keeps the inode, so the bind mount of a
        # container that is already running sees the refreshed cookie.
        cat -- "$source" >"$STABLE_XAUTHORITY" 2>/dev/null || true
    fi
    # Always provide a mount source. Without a cookie, GUI access still works
    # through `xhost +local:root` in x11_prepare.
    touch -- "$STABLE_XAUTHORITY" 2>/dev/null || true

    if [[ -f "$STABLE_XAUTHORITY" ]]; then
        export XAUTHORITY="$STABLE_XAUTHORITY"
    elif [[ -n "$source" && -f "$source" ]]; then
        # Last resort if ~/.cache is not writable: use the original cookie.
        export XAUTHORITY="$source"
    else
        export XAUTHORITY="$HOME/.Xauthority"
    fi
}

prepare_xauthority

########################################
# Container engine
########################################
if command -v podman >/dev/null 2>&1; then
    ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
    ENGINE=docker
else
    die "neither podman nor docker is installed"
fi

# Run a compose command with the selected engine (ROS_DISTRO must be exported).
#
# podman-compose can inject extra arguments into the `podman build` calls it
# makes. We force the docker image format: podman's default (OCI) here ignores
# the Containerfile's SHELL instruction and produces images docker cannot load.
COMPOSE_GLOBAL_ARGS=()
if [[ "$ENGINE" == podman ]] \
        && command -v podman-compose >/dev/null 2>&1 \
        && podman-compose --help 2>/dev/null | grep -q -- '--podman-build-args'; then
    COMPOSE_GLOBAL_ARGS=(--podman-build-args="--format docker")
fi

compose() {
    "$ENGINE" compose ${COMPOSE_GLOBAL_ARGS[@]+"${COMPOSE_GLOBAL_ARGS[@]}"} "$@"
}

########################################
# Distro helpers
########################################
image_name()      { printf 'ros2:%s' "$1"; }
container_name()  { printf 'ros2_%s' "$1"; }

require_distro() {
    local distro="${1:-}" known=0 d
    [[ -n "$distro" ]] || die "no ROS 2 distro given (try one of: ${SUPPORTED_DISTROS[*]})"
    if [[ ! "$distro" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
        die "invalid distro name: '$distro'"
    fi
    for d in "${SUPPORTED_DISTROS[@]}"; do
        if [[ "$d" == "$distro" ]]; then
            known=1
        fi
    done
    if (( ! known )); then
        warn "'$distro' is not a known distro (${SUPPORTED_DISTROS[*]}); trying anyway"
    fi
}

image_exists() {
    # Works for both podman and docker.
    "$ENGINE" image inspect "$(image_name "$1")" >/dev/null 2>&1
}

container_exists() {
    local names
    names=$("$ENGINE" ps -a --format '{{.Names}}' 2>/dev/null || true)
    grep -Fxq "$(container_name "$1")" <<<"$names"
}

container_running() {
    local names
    names=$("$ENGINE" ps --format '{{.Names}}' 2>/dev/null || true)
    grep -Fxq "$(container_name "$1")" <<<"$names"
}

# Containers created by the old (pre-compose) ./run do not carry compose
# labels and would clash with `podman compose up`, so they get replaced.
container_is_compose_managed() {
    local labels
    labels=$("$ENGINE" inspect -f '{{json .Config.Labels}}' "$(container_name "$1")" 2>/dev/null || echo null)
    [[ "$labels" == *compose.project* ]]
}

# Containers created before the stable Xauthority copy above baked a
# /tmp/xauth_* path into their mounts. Once that file is gone at reboot, the
# container cannot be started at all (podman fails before the entrypoint runs),
# so it can only be recreated.
xauthority_mount_missing() {
    local source
    source=$("$ENGINE" inspect -f \
        '{{range .Mounts}}{{if eq .Destination "/root/.Xauthority"}}{{.Source}}{{end}}{{end}}' \
        "$(container_name "$1")" 2>/dev/null || true)
    [[ -n "$source" && ! -e "$source" ]]
}

# The command a container/image runs as PID 1, as JSON (e.g.
# `["/ros_entrypoint.sh"]`). Used to recognise containers and images built
# before the entrypoint was made mode-neutral: those have tmux as PID 1, so
# `./run --no-tmux` cannot work on them until they are recreated.
container_cmd() {
    "$ENGINE" inspect -f '{{json .Config.Cmd}}' "$(container_name "$1")" 2>/dev/null || echo null
}

image_cmd() {
    "$ENGINE" image inspect -f '{{json .Config.Cmd}}' "$(image_name "$1")" 2>/dev/null || echo null
}

# Distros that have a local ros2:<distro> image, one per line, sorted.
built_distros() {
    local images
    images=$("$ENGINE" images --format '{{.Repository}} {{.Tag}}' 2>/dev/null || true)
    awk '$1 ~ /(^|\/)ros2$/ && $2 != "<none>" {print $2}' <<<"$images" | sort -u
}

# Keep ./available_distros in sync with what is actually built.
refresh_distros_file() { built_distros >"$DISTROS_FILE"; }

########################################
# GUI (X11) forwarding
########################################
x11_prepare() {
    # The container reads the cookie from /root/.Xauthority (see compose.yaml).
    touch "$XAUTHORITY" 2>/dev/null || true

    if [[ -z "${DISPLAY:-}" ]]; then
        warn "DISPLAY is not set - the container will start without GUI forwarding"
        return 0
    fi
    if ! command -v xhost >/dev/null 2>&1; then
        warn "'xhost' not found - GUI apps inside the container may fail to open"
        return 0
    fi
    # Rootless containers connect to X as your own user, rootful ones as
    # 'root'; grant both so GUIs work either way (the mounted Xauthority
    # cookie is the fallback).
    if ! { xhost +local:root && xhost +SI:localuser:root; } >/dev/null 2>&1; then
        warn "could not run 'xhost' - GUI apps inside the container may fail to open"
    fi
}

########################################
# Status output
########################################
print_status() {
    local distro status
    local built
    built=$(built_distros)

    if [[ -z "$built" ]]; then
        echo "No ROS 2 images built yet - './run <distro>' builds one automatically."
    else
        echo "Available distros:"
        while IFS= read -r distro; do
            status="image built"
            if container_running "$distro"; then
                status="running"
            elif container_exists "$distro"; then
                status="container stopped"
            fi
            printf '    %-12s %s\n' "$distro" "$status"
        done <<<"$built"
    fi
    echo "Supported distros: ${SUPPORTED_DISTROS[*]}"
}
