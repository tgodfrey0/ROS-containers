#!/bin/bash

# Function to check if podman is available and being used as docker
is_podman() {
    if command -v docker &> /dev/null; then
        if docker --version | grep -qi "podman"; then
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

# Set the build command based on whether it's Docker or Podman
if is_podman; then
    cmd="podman"
else
    cmd="docker"
fi

# Check if ROS_DISTRO argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ROS_DISTRO>"
    exit 1
fi

ROS_DISTRO=$1
shift  # Remove the first argument

# If the distro container has already been built
if grep -q "^$ROS_DISTRO$" ./available_distros; then
    # Build the Docker image
    $cmd rm ros2_${ROS_DISTRO}
    $cmd rmi $($cmd images -f "tag=${ROS_DISTRO}" -q)
    $cmd rmi $($cmd images -f "dangling=true" -q)

    # Remove the distro name
    sed -i "/^$ROS_DISTRO$/d" ./available_distros
    echo "Removed $ROS_DISTRO from available distros."
else
    echo "$ROS_DISTRO has not been built."
fi
