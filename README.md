# ROS Containers

ROS2 can be run in containers, but this can be a pain to set up. We provide a set of Dockerfiles that can be used to build ROS2 containers.

If `podman` is installed, these scripts will use it instead of `docker`. This is due to the various benefits of using `podman` over `docker`, such as improved security and resource efficiency. If `podman` is not installed, the scripts will use `docker`.

## Installation

First, ensure that `podman` is installed.

Then we must build the container image.

```bash
./build.sh <ROS2_DISTRO>
```

For example, to build a container for ROS2 Foxy, you would run `./build foxy`.

Once a container has been built, the distribution name is written to the file `./available_distros`, so to see which distributions have been built, run `cat ./available_distros`.

## Usage

Once a container has been built, you can run it using the following command:

```bash
./run.sh <ROS2_DISTRO>
```

For example, to run a container for ROS2 Foxy, you would run `./run foxy`.
