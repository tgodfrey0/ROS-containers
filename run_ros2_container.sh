#!/bin/bash

# Check if ROS_DISTRO argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ROS_DISTRO>"
    exit 1
fi

ROS_DISTRO=$1
CONTAINER_NAME="ros2_${ROS_DISTRO}"

xhost +local:root

if [ ! "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Container does not exist! Creating..."
    docker run -it \
               --name $CONTAINER_NAME \
               -v /dev:/dev \
               -v /home/$(whoami)/:/home/$(whoami)/ \
               -v /tmp/.X11-unix:/tmp/.X11-unix \
               --network="host" \
               --privileged \
               -w /home/$(whoami) \
               ros2:${ROS_DISTRO}
else
    if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        echo "Container is not running! Starting..."
        docker start -i $CONTAINER_NAME
    else
        echo "Attaching to running container..."
        docker attach $CONTAINER_NAME
    fi
fi
