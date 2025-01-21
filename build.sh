#!/bin/bash

is_podman() {
    if command -v podman &> /dev/null; then
        return 0
    elif command -v docker &> /dev/null; then
        return 1
    else
        echo "Neither Podman nor Docker is installed"
        exit 1
    fi
}

if is_podman; then
    CMD="podman build --format docker"
else
    CMD="docker build"
fi

# Check if ROS_DISTRO argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ROS_DISTRO>"
    exit 1
fi

ROS_DISTRO=$1
CONTAINER_NAME="ros2_${ROS_DISTRO}"
IMAGE_NAME="ros2:${ROS_DISTRO}"

# If the distro container has not already been built
if ! grep -q "^$ROS_DISTRO$" ./available_distros; then
    # Build the image
    if $CMD --squash \
            --build-arg ROS_DISTRO=$ROS_DISTRO \
            --env DISPLAY=$DISPLAY \
            -t ${IMAGE_NAME} \
            -f Containerfile .; then
        # Write the distro name to a file only if the build command succeeds
        echo "$ROS_DISTRO" >> ./available_distros
        echo "Added $ROS_DISTRO to available distros."
    else
        echo "Build failed for $ROS_DISTRO. Not adding to available distros."
    fi
else
    echo "$ROS_DISTRO is already in the list of available distros. Remove the container before building a new one."
fi
