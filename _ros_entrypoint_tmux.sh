#!/bin/bash
set -e

# Source ROS setup
source "/opt/ros/${ROS_DISTRO}/setup.bash"

# Function to create or attach to tmux session
start_or_attach_tmux() {
    if ! tmux has-session -t ros2_session 2>/dev/null; then
        tmux new-session -d -s ros2_session
    fi
    exec tmux attach-session -t ros2_session
}

# If no command is provided, start or attach to tmux
if [ "$#" -eq 0 ]; then
    start_or_attach_tmux
else
    exec "$@"
fi
