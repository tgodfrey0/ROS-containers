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

# Remove the container associated with the ROS distribution, if it exists
$cmd rm -f ros2_${ROS_DISTRO} 2>/dev/null

# Remove the image associated with the ROS distribution, if it exists
$cmd rmi -f localhost/ros2:${ROS_DISTRO} 2>/dev/null

# Clean up dangling images (images not tagged and not referenced by any container)
dangling_images=$($cmd images -f "dangling=true" -q)
if [ ! -z "$dangling_images" ]; then
    $cmd rmi -f $dangling_images  # Force remove dangling images
fi

# Remove the distro name from available_distros file, if it exists
sed -i "/^$ROS_DISTRO$/d" ./available_distros

echo "Cleanup completed for ROS distribution: $ROS_DISTRO."
