#!/bin/bash

# Check if ROS_DISTRO argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ROS_DISTRO>"
    if [ -f ./available_distros ]; then
        echo "Available distros:"
        while IFS= read -r line; do
            echo "    - $line"
        done < ./available_distros
    else
        echo "Error: no containers found."
        echo "Please build the ROS container first."
    fi
    exit 1
fi

ROS_DISTRO=$1
CONTAINER_NAME="ros2_${ROS_DISTRO}"

xhost +local:root
XAUTH=$HOME/.Xauthority
touch $XAUTH


if [ ! "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Container does not exist! Creating..."
    docker run -it \
               --name $CONTAINER_NAME \
               -v /dev:/dev \
               -v /home/$(whoami)/:/home/$(whoami)/ \
               -v /tmp/.X11-unix:/tmp/.X11-unix \
               -v $HOME/.Xauthority:/root/.Xauthority \
               --network="host" \
               --privileged \
               -w /home/$(whoami) \
               ros2:${ROS_DISTRO}
else
    if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        echo "Container is not running! Starting..."
        docker start -i $CONTAINER_NAME
    fi
    echo "Attaching to running container..."
    docker attach $CONTAINER_NAME
fi
