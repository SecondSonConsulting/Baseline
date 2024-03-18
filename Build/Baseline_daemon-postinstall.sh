#!/bin/zsh --no-rcs

# Set variables for path/name
launchDPath="/Library/LaunchDaemons"
launchDName="com.secondsonconsulting.baseline"

# Function to exit with an error message
exit_with_error() {
    echo "Error: $1" >&2
    exit 1
}

# Load the launch daemon
launchctl bootstrap system "$launchDPath/$launchDName.plist" > /dev/null 2>&1
bootstrap_result=$?

# Test if the bootstrap command failed
if [ "$bootstrap_result" -ne 0 ]; then
    exit_with_error "Failed to load the launch daemon."
fi

# Check if the launch daemon is actually running
launchctl list "$launchDName" > /dev/null 2>&1
list_result=$?

# Exit fail if the launch daemon isn't loaded
if [ "$list_result" -ne 0 ]; then
    exit_with_error "Launch daemon is not running."
fi

# Successful exit
exit 0
