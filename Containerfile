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

RUN curl https://packages.osrfoundation.org/gazebo.gpg --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null
RUN apt-get update -y
RUN case "${ROS_DISTRO}" in \
        "humble") \
            apt-get install -y --no-install-recommends gz-fortress ros-${ROS_DISTRO}-ros-gz \
            ;; \
        "iron") \
            apt-get install -y --no-install-recommends gz-fortress ros-${ROS_DISTRO}-ros-gz \
            ;; \
        "jazzy") \
            apt-get install -y --no-install-recommends gz-harmonic ros-${ROS_DISTRO}-ros-gz \
            ;; \
        "kilted") \
            apt-get install -y --no-install-recommends gz-ionic ros-${ROS_DISTRO}-ros-gz \
            ;; \
        "rolling") \
            apt-get install -y --no-install-recommends gz-ionic ros-${ROS_DISTRO}-ros-gz \
            ;; \
        *) \
            echo "Warning: Unspecified or unsupported ROS_DISTRO for Gazebo Sim. Attempting to install ros-${ROS_DISTRO}-ros-gz, but specific Gazebo Sim version might be missing." && \
            apt-get install -y --no-install-recommends ros-${ROS_DISTRO}-ros-gz \
            ;; \
    esac
ENV IGN_IP=127.0.0.1

RUN apt-get install -y --no-install-recommends \
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
  ros-${ROS_DISTRO}-ros-gz \
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
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain 1.75.0 -y || true
ENV PATH=/root/.cargo/bin:$PATH
RUN pip install git+https://github.com/colcon/colcon-cargo.git git+https://github.com/colcon/colcon-ros-cargo.git || true

########################################
# Install Pixi #
########################################
RUN curl -fsSL https://pixi.sh/install.sh | bash

########################################
# ROS 2 environment + tab completion #
########################################
# tmux panes start a fresh bash that only reads .bashrc. Sourcing setup.bash
# there gives every shell the full ROS environment and registers the
# argcomplete-based `ros2` completion (package names for `ros2 run` /
# `ros2 launch`, verbs, options, launch files).
RUN printf '\n# ROS 2 environment and tab completion in every interactive shell\nif [ -n "${ROS_DISTRO:-}" ] && [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then\n    . "/opt/ros/${ROS_DISTRO}/setup.bash"\nfi\n' >> /root/.bashrc

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
