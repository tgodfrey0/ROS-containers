#!/bin/bash

is_podman() {
    if command -v docker &> /dev/null; then
        if docker --version | grep -qi "podman"; then
            echo "Podman detected"
            return 0  # True, it's podman
        else
            return 1  # False, it's docker
        fi
    elif command -v podman &> /dev/null; then
        return 0  # True, it's podman
    else
        echo "Neither Docker nor Podman is installed."
        exit 1
    fi
}

if is_podman; then
    build_command="podman build --format docker"
else
    build_command="docker build"
fi


# Check if ROS_DISTRO argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ROS_DISTRO>"
    exit 1
fi

ROS_DISTRO=$1
shift  # Remove the first argument

# If the distro container has not already been built
if ! grep -q "^$ROS_DISTRO$" ./available_distros; then
    # Build the Docker image
    $build_command --build-arg ROS_DISTRO=$ROS_DISTRO \
                -t ros2:${ROS_DISTRO} \
                "$@" .

    # Write the distro name to a file
    echo "$ROS_DISTRO" >> ./available_distros
    echo "Added $ROS_DISTRO to available distros."
else
    echo "$ROS_DISTRO is already in the list of available distros. Remove the container before building a new one."
fi
