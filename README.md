# ROS Containers

Run ROS 2 in a container with one command — GUI forwarding and a host network
(so DDS discovery and physical robots just work) included.

Everything is defined in [`compose.yaml`](./compose.yaml) and driven by
`podman compose` (falls back to `docker compose` if podman is missing).

## Requirements

- `podman` (and `podman-compose`, usually packaged with it)
  - RHEL/Fedora: `sudo dnf install podman podman-compose`
- An X11 session on the host if you want GUIs (`rviz`, `rqt`, ...)

## Quick start

```bash
./run jazzy
```

That's it. The first run builds the image (`ros2:jazzy`), starts the
container and drops you into a tmux session inside it, with:

- **GUI forwarding** — `DISPLAY`, `/tmp/.X11-unix` and your Xauthority cookie
  are passed through, so `rviz` and friends open on your host screen.
- **Host networking** — ROS 2 nodes in the container see the LAN, DDS
  discovery works, and you can talk to physical robots without port mapping
  headaches.
- **Hardware access** — `/dev`, `CAP_NET_ADMIN` and `privileged` for serial
  ports, CAN adapters and network configuration.
- **Your home directory** mounted at the same path, as the working directory.

Prefer no tmux? `./run --no-tmux jazzy` gives you a plain bash shell in the
container instead (ROS environment included), and switching between the two
never rebuilds or recreates the container.

`./run humble`, `./run iron`, ... work the same way; the image is built
automatically the first time you ask for a distro.

## Commands

| Command | What it does |
|---|---|
| `./run <distro>` | Build if missing, start (or attach to) the container, attach tmux |
| `./run --no-tmux <distro>` | Same, but attach a plain bash shell instead of tmux |
| `./run --build <distro>` | Rebuild the image and recreate the container (use after editing `Containerfile`) |
| `./run <distro> -- <cmd>` | Run a single command in the container (e.g. `./run jazzy -- ros2 topic list`) |
| `./remove <distro>` | Stop and delete the container and image |
| `./remove --all` | Remove everything that has been built |
| `./run` (no arguments) | Show usage plus which distros are built/running |

Detach from a running container with `Ctrl-g` (instead of the usual
`Ctrl-p Ctrl-q`, because Ctrl-Q often gets eaten by terminal flow control);
it keeps running in the background and `./run <distro>` attaches again. In
`--no-tmux` mode, exiting the shell (`Ctrl-D`) does the same: the container
stays up. Stop it for good with `./remove <distro>`.

## Supported distros

`humble`, `iron`, `jazzy`, `kilted`, `rolling` — see `SUPPORTED_DISTROS` in
[`lib.sh`](./lib.sh) and the Gazebo case statement in
[`Containerfile`](./Containerfile) (other distros are attempted with a
warning).

`./available_distros` is kept in sync automatically and simply mirrors which
`ros2:<distro>` images currently exist.

## How it works

`compose.yaml` defines one service, `ros2`, parameterised by `ROS_DISTRO`:

```yaml
name: ros2
services:
  ros2:
    image: ros2:${ROS_DISTRO}
    build: { context: ., dockerfile: Containerfile, args: { ROS_DISTRO: ${ROS_DISTRO} } }
    container_name: ros2_${ROS_DISTRO}
    network_mode: host        # DDS + physical robots
    privileged: true          # hardware access
    cap_add: [CAP_NET_ADMIN]
    tty: true
    stdin_open: true
    volumes:
      - /dev:/dev
      - ${HOME}:${HOME}
      - /tmp/.X11-unix:/tmp/.X11-unix        # GUI forwarding
      - ${XAUTHORITY}:/root/.Xauthority:ro
    environment:
      DISPLAY: ${DISPLAY:-}
      ...
```

The scripts are thin wrappers: they validate the distro, export
`ROS_DISTRO`/`XAUTHORITY`, run `xhost +local:root` (so the container may
connect to your X server), and then call `podman compose`.

The container's PID 1 (`/ros_entrypoint.sh`, see [`Containerfile`](./Containerfile))
only keeps the container alive — tmux is **not** started at container start.
`./run` picks what to attach afterwards, through `podman exec`:

- `./run <distro>` → `tmux new-session -A -s ros2_session` (creates the
  session on first use, re-attaches later)
- `./run --no-tmux <distro>` → plain `bash`
- `./run <distro> -- <cmd>` → the command itself, with
  `/opt/ros/$ROS_DISTRO/setup.bash` sourced first (the container's
  configured environment does not put `ros2` on `PATH`)

So tmux vs. plain shell is a per-run choice: nothing about the container
needs rebuilding or recreating to switch. Only `./remove` / `./run --build`
recreate it, because they rebuild the image.

You can drive compose yourself just as well:

```bash
export ROS_DISTRO=jazzy
podman compose build        # build the image
podman compose up -d        # start (builds automatically if the image is missing)
podman exec -it ros2_jazzy bash                # plain shell inside
podman exec -it ros2_jazzy tmux attach -t ros2_session   # or the tmux session
podman compose down --rmi all   # remove container + image
```

The container itself only stays alive (its PID 1 is `/ros_entrypoint.sh`);
everything else — tmux, a shell, a command — is `podman exec`'d into it by
`./run`, which is why `--no-tmux` costs nothing.

### Notes

- `DISPLAY` must be set for GUIs; if you are in a plain SSH session without
  X forwarding, the container still starts, just without GUI support.
- **Package installs are not permanent by default.** `apt install` inside the
  container survives plain `./run` restarts, but `./run --build` and
  `./remove` recreate the container from the image and discard it. To keep
  packages for good, add them to the `Containerfile` (or avoid rebuilding).
- After changing `compose.yaml`, run `./remove <distro>` once so the new
  configuration is applied (`./run` deliberately never recreates an existing
  container).
- After changing `Containerfile`, run `./run --build <distro>` to pick up
  the changes.
- tmux vs. a plain shell is decided by `./run` when it attaches, never by
  the container, so `./run <distro>` and `./run --no-tmux <distro>` can be
  used interchangeably on the same container without any rebuild.
- The scripts pass `--podman-build-args="--format docker"` to podman-compose:
  podman's default OCI format ignores the `SHELL` instruction in the
  Containerfile and produces images that docker cannot load.
- Only X11 is wired up. For Wayland, add your Wayland socket
  (`$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY`) as another volume in
  `compose.yaml`.
