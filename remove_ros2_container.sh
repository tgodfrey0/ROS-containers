#!/bin/bash

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
    docker remove ros2_${ROS_DISTRO}

    # Remove the distro name
    sed -i "/^$ROS_DISTRO$/d" ./available_distros
    echo "Removed $ROS_DISTRO from available distros."
else
    echo "$ROS_DISTRO has not been built."
fi
