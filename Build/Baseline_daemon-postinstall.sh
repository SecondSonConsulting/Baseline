#!/bin/zsh
#set -x

#Set variables for path/name
launchDPath="/Library/LaunchDaemons"
launchDName="com.secondsonconsulting.baseline"

#Load the launch daemon
launchctl bootstrap system "$launchDPath"/"$launchDName".plist > /dev/null 2>&1
result=$(echo $?)

#Test if the bootstrap command failed
if [ "$result" != 0 ]; then
	exit 1
fi

#Check if the launch daemon is actually running
launchctl list "$launchDName" > /dev/null 2>&1
LIST_result=$(echo $?)

#Exit fail if the launch daemon isn't loaded
if [ "$result" != 0 ]; then
	exit 1
fi

exit 0