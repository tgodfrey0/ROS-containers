########################################
# Distro argument #
########################################
ARG ROS_DISTRO

########################################
# Base image #
########################################
FROM osrf/ros:${ROS_DISTRO}-desktop AS base

########################################
# Other arguments #
########################################
ARG DEBIAN_FRONTEND=noninteractive

########################################
# Environment variables #
########################################
ENV ROS_DISTRO=${ROS_DISTRO}
ENV ROS_VERSION=2
ENV ROS_PYTHON_VERSION=3
ENV ROS_PACKAGE_PATH=/opt/ros/${ROS_DISTRO}/share

########################################
# Set the shell #
########################################
SHELL ["/bin/bash", "-c"]

########################################
# Install packages #
########################################
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y \
  ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
  ros-${ROS_DISTRO}-rosidl-generator-dds-idl \
  ros-${ROS_DISTRO}-ament-cmake \
  ros-${ROS_DISTRO}-ament-cmake-ros \
  ros-${ROS_DISTRO}-geometry-msgs \
  ros-${ROS_DISTRO}-std-msgs \
  ros-${ROS_DISTRO}-tf2-ros \
  ros-${ROS_DISTRO}-rosidl-default-generators \
  ros-${ROS_DISTRO}-ament-lint-common \
  ros-${ROS_DISTRO}-rclcpp-action \
  ros-${ROS_DISTRO}-xacro \
  ros-${ROS_DISTRO}-launch-ros \
  ros-${ROS_DISTRO}-rqt-robot-steering \
  libboost-all-dev \
  libyaml-cpp-dev \
  iproute2 \
  iputils-ping \
  nano \
  ninja-build \
  tmux \
  git \
  xclip \
  xsel \
  x11-apps \
  xauth \
  python3-pytest

########################################
# Setup for X11 forwarding #
########################################
RUN mkdir -p /root/.ssh
RUN chmod 700 /root/.ssh
RUN touch /root/.Xauthority

########################################
# Install ROS2 Rust #
########################################
RUN apt-get install -y \
  libclang-dev \
  python3-pip \
  python3-vcstool
RUN rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain 1.75.0 -y
ENV PATH=/root/.cargo/bin:$PATH
# RUN pip install --upgrade pytest
RUN pip install git+https://github.com/colcon/colcon-cargo.git git+https://github.com/colcon/colcon-ros-cargo.git

########################################
# Copy tmux configuration #
########################################
COPY tmux.conf /root/.tmux.conf

########################################
# Set entrypoint and default command #
########################################
COPY _ros_entrypoint_tmux.sh /ros_entrypoint_tmux.sh
RUN chmod +x /ros_entrypoint_tmux.sh

# Set the entrypoint
CMD ["/ros_entrypoint_tmux.sh"]
