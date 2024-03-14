#!/bin/zsh --no-rcs

# Function to exit with an error message
exit_with_error() {
    echo "Error: $1" >&2
    exit 1
}

# Set path and name variables
launchDPath="/Library/LaunchDaemons"
launchDName="com.secondsonconsulting.baseline"

# Check if the launch daemon is running
launchctl list "$launchDName" > /dev/null 2>&1
list_result=$?

# If daemon is running, attempt to unload and remove it
if [ "$list_result" -eq 0 ]; then
    launchctl bootout system/"$launchDName"
    bootout_result=$?
    
    if [ "$bootout_result" -ne 0 ]; then
        exit_with_error "Failed to unload the launch daemon."
    fi

    # Remove plist file
    rm "$launchDPath/$launchDName.plist" || true
fi

# Successful exit
exit 0
