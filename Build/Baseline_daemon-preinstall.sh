#!/bin/zsh
#set -x

launchDPath="/Library/LaunchDaemons"
launchDName="com.secondsonconsulting.baseline"

launchctl list "$launchDName" > /dev/null 2>&1
listResult=$(echo $?)

if [ "$listResult" = 0 ]; then
	launchctl bootout system/"$launchDName"
	unloadResult=$(echo $?)
	if [ "$unloadResult" != 0 ]; then
		echo "UNLOAD FAILED"
	fi
	rm "$launchDPath"/"$launchDName".plist
fi

exit 0