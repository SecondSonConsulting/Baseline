#!/bin/zsh
set -x
#dryRun=true

#   Written by Trevor Sysock of Second Son Consulting
#   @BigMacAdmin on the MacAdmins Slack
#   trevor@secondsonconsulting.com

scriptVersion="v.1.3beta1"

########################################################################################################
########################################################################################################
##
##      DEFINE INITIAL VARIABLES
##
########################################################################################################
########################################################################################################

if [ "${1}" = '--version' ]; then
    echo "$(basename $0) by Second Son Consulting - v. $scriptVersion"
    exit 0
fi

#################################
#   Declare file/folder paths   #
#################################
#Baseline files/folders
BaselineConfig="/Library/Managed Preferences/com.secondsonconsulting.baseline.plist"
BaselineDir="/usr/local/Baseline"
customConfigPlist="$BaselineDir/BaselineConfig.plist"
logFile="/var/log/Baseline.log"
BaselinePath="$BaselineDir/Baseline.sh"
BaselineScripts="$BaselineDir/Scripts"
BaselinePackages="$BaselineDir/Packages"
BaselineIcons="$BaselineDir/Icons"
BaselineLaunchDaemon="/Library/LaunchDaemons/com.secondsonconsulting.baseline.plist"
BaselineTempIconsDir="$(mktemp -d /var/tmp/baselineTmpIcons.XXXX)"
ScriptOutputLog="/var/log/Baseline-ScriptsOutput.log"

#Binaries
pBuddy="/usr/libexec/PlistBuddy"
dialogPath="/usr/local/bin/dialog"
dialogAppPath="/Library/Application Support/Dialog/Dialog.app"
installomatorPath="/usr/local/Installomator/Installomator.sh"

#Other stuff
dialogCommandFile=$(mktemp /var/tmp/baselineDialog.XXXXXX)
dialogJsonFile=$(mktemp /var/tmp/baselineJson.XXXX)
dialogFailedJsonFile=$(mktemp /var/tmp/baselineFailedJson.XXXX)
expectedDialogTeamID="PWA5E9TQ59"

########################################################################################################
########################################################################################################
##
##      DEFINE FUNCTIONS
##
########################################################################################################
########################################################################################################

#################################
#   Logging and Housekeeping    #
#################################

function check_root()
{

# check we are running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "ERROR: This script must be run as root **EXITING**"
  exit 1
fi
}

function make_directory()
{
    if [ ! -d "${1}" ]; then
        debug_message "Folder does not exist. Making it: ${1}"
        mkdir -p "${1}"
    fi
}

#Used only for debugging. Gives feedback into standard out if verboseMode=1, also to $logFile if you set it
function debug_message()
{
    if [ "$verboseMode" = 1 ]; then
    	/bin/echo "DEBUG: $*"
    fi
}

#Publish a message to the log (and also to the debug channel)
function log_message()
{
    if [ -e "$logFile" ]; then
    	/bin/echo "$(date): $*" >> "$logFile"
    fi

    if [ "$verboseMode" = 1 ]; then
    	debug_message "$*"
    fi
}

#Report messages go to our report, but also pass through log_message (and thus, also to debug_message)
function report_message()
{
    /bin/echo "$@" >> "$reportFile"
    log_message "$@"
}

# Initiate logging
function initiate_logging()
{
if ! touch "$logFile" ; then
    debug_message "ERROR: Logging fail. Cannot create log file"
    exit 1
else
    log_message "Baseline.sh initiated"
fi
}

#Only delete something if the variable has a value!
function rm_if_exists()
{
    if [ -n "${1}" ] && [ -e "${1}" ];then
        /bin/rm -rf "${1}"
    fi
}

function initiate_report()
{
    reportFile="/usr/local/Baseline/Baseline-Report.txt"
    if ! touch "$reportFile" ; then
        debug_message "ERROR: Reporting fail. Cannot create report file"
        exit 1
    else
        rm_if_exists "$reportFile"
        report_message "Report created: $(date)"
    fi
}

#Define our script exit process. Usage: cleanup_and_exit 'exitcode' 'exit message'
function cleanup_and_exit()
{
    # Check if we are going to restart
    check_restart_option

    # Check if we are leaving the Baseline working directory or deleting
    cleanupAfterUse=$($pBuddy -c "Print :CleanupAfterUse" "$BaselineConfig")

    if  [ $cleanupAfterUse = "false" ]; then
        cleanupBaselineDirectory="false"
    else
        cleanupBaselineDirectory="true"
    fi

    # Log message
    log_message "Exiting: $2"

    # Delete the Baseline LaunchDaemon
    # Doing this in a loop because I've seen edge cases where it failed unexpectedly and it is high impact.
    while [ -e "$BaselineLaunchDaemon" ]; do
        rm_if_exists "$BaselineLaunchDaemon"
        sleep 1
    done

    kill "$caffeinatepid"
    dialog_command "quit:" 
    rm_if_exists "$dialogCommandFile"
    rm_if_exists "$dialogJsonFile"
    rm_if_exists "$BaselineTempIconsDir"
    if [ "$dryRun" != true ] && [ "$cleanupBaselineDirectory" = "true" ] ; then
        rm_if_exists "$BaselineDir"
    fi
    exit "$1"
}

# This function doesn't always shut down, but I'm leaving the name in place for now at least.
# Usage: cleanup_and_exit 'exitcode' 'exit message'
function cleanup_and_restart()
{
    # Check if we are going to restart
    check_restart_option

    # Check if we are leaving the Baseline working directory or deleting
    cleanupAfterUse=$($pBuddy -c "Print :CleanupAfterUse" "$BaselineConfig")

    if  [ "$cleanupAfterUse" = "false" ]; then
        cleanupBaselineDirectory="false"
    else
        cleanupBaselineDirectory="true"
    fi

    log_message "Exiting: $2"
    # Delete the LaunchDaemon. Saw an edge case where it didn't delete once, so I made it a while loop.
    while [ -e "$BaselineLaunchDaemon" ]; do
        rm_if_exists "$BaselineLaunchDaemon"
        sleep 1
    done
    # Kill our caffeinate command
    kill "$caffeinatepid"
    # Close dialog window
    dialog_command "quit:"
    # Delete dialog command file 
    rm_if_exists "$dialogCommandFile"
    # Delete dialog json file
    rm_if_exists "$dialogJsonFile"
    # Delete dialog failed json file
    rm_if_exists "$dialogFailedJsonFile"
    # Delete icons tmp directory
    rm_if_exists "$BaselineTempIconsDir"

    # Check if we are deleting the Baseline working directory and do it
    if  [ $cleanupBaselineDirectory = "true" ]; then
        rm_if_exists "$BaselineDir"
    fi

    # Determine exit configuration
    # If ForceRestart is set to false
    if [ $forceRestart = "false" ]; then
        echo "Force Restart is set to false. Exiting"
        exit "$1"
    # If Force Log Out is set to true, force restart is false, and dry run is off
    elif [ $forceLogOut = "true" ] && [ "$dryRun" != true ]; then
        echo "Force Log Out is set to true. Exiting"
        osascript -e "tell application \"/System/Library/CoreServices/loginwindow.app\" to «event aevtrlgo»"
        exit "$1"
    # If the script is in DryRun mode
    elif [ "$dryRun" = true ]; then
        echo "this is where <shutdown -r now> or logout would go"
        exit "$1"
    fi

    # Shutting down
    shutdown -r now
}

function no_sleeping()
{

    /usr/bin/caffeinate -d -i -m -u &
    caffeinatepid=$!

}

# execute a dialog command
function dialog_command(){
    /bin/echo "$@"  >> $dialogCommandFile
    sleep .1
}

#This function is modified from the awesome one given to us via Adam Codega. Thanks Adam!
#https://github.com/acodega/dialog-scripts/blob/main/dialogCheckFunction.sh

function install_dialog()
{

    # Check for Dialog and install if not found. We'll try 10 times before exiting the script with a fail.
    dialogInstallAttempts=0
    while [ ! -e "$dialogAppPath" ] && [ "$dialogInstallAttempts" -lt 10 ]; do
        # If SwiftDialog.pkg exists in the Packages folder check the TeamID is valid, and install it
        localDialogTeamID=$(/usr/sbin/spctl -a -vv -t install "$BaselinePackages/SwiftDialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
        if [ "$expectedDialogTeamID" = "$localDialogTeamID" ]; then
                /usr/sbin/installer -pkg "$BaselinePackages/SwiftDialog.pkg" -target /  > /dev/null 2>&1
        # If Installomator is already here use that
        elif [ -e "$installomatorPath" ]; then
            "$installomatorPath" swiftdialog INSTALL=force NOTIFY=silent BLOCKING_PROCESS_ACTION=ignore > /dev/null 2>&1
            dialogInstallAttempts=$((dialogInstallAttempts+1))
        else
            # Get the URL of the latest PKG From the Dialog GitHub repo
            # Expected Team ID of the downloaded PKG
            dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
            log_message "Dialog not found. Installing."
            # Create temporary working directory
            workDirectory=$( /usr/bin/basename "$0" )
            tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
            # Download the installer package
            /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/SwiftDialog.pkg"
            # Verify the download
            teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/SwiftDialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
            # Install the package if Team ID validates
            if [ "$expectedDialogTeamID" = "$teamID" ]; then
                /usr/sbin/installer -pkg "$tempDirectory/SwiftDialog.pkg" -target /  > /dev/null 2>&1
            fi
            #If Dialog wasn't installed, wait 5 seconds and increase the attempt count
            if [ ! -e "$dialogAppPath" ]; then
                log_message "Dialog installation failed."
                sleep 5
                dialogInstallAttempts=$((dialogInstallAttempts+1))
            fi
            # Remove the temporary working directory when done
            rm_if_exists "$tempDirectory"
        fi
    done
}

function install_installomator()
{

    # Check for Installomator and install if not found. We'll try 10 times before exiting the script with a fail.
    installomatorInstallAttempts=0
    while [ ! -e "$installomatorPath" ] && [ "$installomatorInstallAttempts" -lt 10 ]; do
        # Check if there is a local Installomator.pkg, and if so run it.
        if [ -e "${BaselinePackages}/Installomator.pkg" ]; then
            /usr/sbin/installer -pkg "${BaselinePackages}/Installomator.pkg" -target /  > /dev/null 2>&1
        else
            # Get the URL of the latest PKG From the Installomator GitHub repo
            # Expected Team ID of the downloaded PKG
            installomatorURL=$(curl --silent -L --fail "https://api.github.com/repos/Installomator/Installomator/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
            expectedTeamID="JME5BW3F3R"
            log_message "Installomator not found. Installing."
            # Create temporary working directory
            workDirectory=$( /usr/bin/basename "$0" )
            tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
            # Download the installer package
            /usr/bin/curl --location --silent "$installomatorURL" -o "$tempDirectory/Installomator.pkg"
            # Verify the download
            teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Installomator.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
            # Install the package if Team ID validates
            if [ "$expectedTeamID" = "$teamID" ]; then
                /usr/sbin/installer -pkg "$tempDirectory/Installomator.pkg" -target /  > /dev/null 2>&1
                installomatorInstallExitCode=$?
            fi
            if [ ! -e "$installomatorPath" ]; then
                log_message "Installomator installation failed."
                sleep 5
                installomatorInstallAttempts=$((installomatorInstallAttempts+1))
            fi
            # Remove the temporary working directory when done
            rm_if_exists "$tempDirectory"
        fi  
    done
}

#Checks if a user is logged in yet, and if not it waits and loops until we can confirm there is a real user
function wait_for_user()
{
    #Set our test to false
    verifiedUser="false"

    #Loop until user is found
    while [ "$verifiedUser" = "false" ]; do
        #Get currently logged in user
        currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
        #Verify the current user is not root, loginwindow, or _mbsetupuser
        if [ "$currentUser" = "root" ] \
            || [ "$currentUser" = "loginwindow" ] \
            || [ "$currentUser" = "_mbsetupuser" ] \
            || [ -z "$currentUser" ] 
        then
        #If we aren't verified yet, wait 1 second and try again
        sleep 1
        else
            #Logged in user found, but continue the loop until Dock and Finder processes are running
            if pgrep -q "dock" && pgrep -q "Finder"; then
                uid=$(id -u "$currentUser")
                log_message "Verified User is logged in: $currentUser UID: $uid"
                verifiedUser="true"
            fi
        fi
    debug_message "Disabling verbose output to prevent logspam while waiting for user at timestamp: $(date +%s)"
    set +x
    done
    set -x
    debug_message "Re-enabling verbose output after finding user at timestamp: $(date +%s)"

}

#Check for custom config. We prioritize this even over a mobileconfig file.
function check_for_custom_plist()
{
    if [ -e $customConfigPlist ]; then
        BaselineConfig="$customConfigPlist"
    fi
}

#Verify configuration file
function verify_configuration_file()
{
    #We need to make sure our configuration file is in place. By the time the user logs in, this should have happened.
    debug_message "Verifying configuration file. Failure here probably means an MDM profile hasn't been properly scoped, or there's a problem with the MDM delivering the profile."
    
    #Set timeout variables
    configFileTimeout=600
    configFileWaiting=0

    # Look for a custom plist
    check_for_custom_plist

    # While the plist or configuration file doesn't exist, wait and timeout at 10 minutes if never found.
    while [ ! -e $BaselineConfig ]; do
        check_for_custom_plist
        #wait 2 seconds
        sleep 2
        debug_message "Configuration file not found"
        configFileWaiting=$((configFileWaiting+2))
        if [ $configFileWaiting -gt $configFileTimeout ]; then
            cleanup_and_exit 1 "ERROR: Configuration file not found within $configFileTimeout seconds. Exiting."
        fi
    done
    debug_message "Configuration file found successfully: $BaselineConfig "
}

function build_installomator_array()
{
    #Set an index internal to this function
    index=0
    #Loop through and test if there is a value in the slot of this index for the given array
    #If this command fails it means we've reached the end of the array in the config file and we exit our loop

    while $pBuddy -c "Print :Installomator:${index}" "$BaselineConfig" > /dev/null 2>&1; do
        #Get the Display Name of the current item
        currentDisplayName=$($pBuddy -c "Print :Installomator:${index}:DisplayName" "$BaselineConfig")
        dialogList+="$currentDisplayName"
        #Done looping. Increase our array value and loop again.
        index=$((index+1))
    done
}

function process_installomator_labels()
{
    #Set an index internal to this function
    currentIndex=0
    #Loop through and test if there is a value in the slot of this index for the given array
    #If this command fails it means we've reached the end of the array in the config file (or there are none) and we exit our loop
    while $pBuddy -c "Print :Installomator:${currentIndex}" "$BaselineConfig" > /dev/null 2>&1; do
        if [ ! -e "$installomatorPath" ]; then
            cleanup_and_exit 1 "ERROR: Installomator failed to install after numerous attempts. Exiting."
        fi
        #Set the current label name
        currentLabel=$($pBuddy -c "Print :Installomator:${currentIndex}:Label" "$BaselineConfig")
        #Check if there are Options defined, and set the variable accordingly
        if $pBuddy -c "Print :Installomator:${currentIndex}:Arguments" "$BaselineConfig" > /dev/null 2>&1; then
            #This label has options defined
            currentArguments=$($pBuddy -c "Print :Installomator:${currentIndex}:Arguments" "$BaselineConfig")
        else
            #This label does not have options defined
            currentArguments=""
        fi
        #Get the display name of the label we're installing. We need this to update the dialog list
        currentDisplayName=$($pBuddy -c "Print :Installomator:${currentIndex}:DisplayName" "$BaselineConfig")
        #Set the current icon
        if $pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig" > /dev/null 2>&1; then
            currentIconPath=$($pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig")
        fi
        #Update the dialog window so that this item shows as "pending"
        dialog_command "listitem: title: $currentDisplayName, status: wait"
        set_progressbar_text "$currentDisplayName"
        #Call installomator with our desired options. Default options first, so that they can be overriden by "currentArguments"
        $installomatorPath $currentLabel ${defaultInstallomatorOptions[@]} $currentArguments > /dev/null 2>&1
        installomatorExitCode=$?
        if [ $installomatorExitCode != 0 ]; then
            report_message "Installomator failed to install: $currentLabel - Exit Code: $installomatorExitCode"
            dialog_command "listitem: title: $currentDisplayName, status: fail"
            #failList+=("$currentDisplayName")
            failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
        else
            report_message "Installomator successfully installed: $currentLabel"
            dialog_command "listitem: title: $currentDisplayName, status: success"
            successList+=("$currentDisplayName")
       fi
        currentIndex=$((currentIndex+1))
        increment_progress_bar
    done
}

# Our main list builder for the Dialog window
function build_dialog_array()
{
    ## Usage: Build the dialog array for the given profile configuration key. $1 is the name of the key
    ## Example: build_dialog_array Scripts | InitialScripts | Packages | Installomator

    # Set the MDM key to the given argument
    configKey="${1}"

    #Set an index internal to this function
    index=0
    #Loop through and test if there is a value in the slot of this index for the given array
    #If this command fails it means we've reached the end of the array in the config file and we exit our loop

    while $pBuddy -c "Print :$configKey:${index}" "$BaselineConfig" > /dev/null 2>&1; do
        #Get the Display Name of the current item
        currentDisplayName=$($pBuddy -c "Print :$configKey:${index}:DisplayName" "$BaselineConfig")
        dialogList+="$currentDisplayName"

		#Get the icon path if populated in the configuration profile
        if $pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig" > /dev/null 2>&1; then
			currentIconPath=$($pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig")
			# Check if Icon is remotely hosted URL
            if [[ ${currentIconPath:0:4} == "http" ]]; then
                report_message "Icon set to URL: $currentIconPath"
            # Check if Icon is an SF Symbol
			elif [[ ${currentIconPath:0:3} == 'SF=' ]]; then
                report_message "Icon set to SF Symbol: $currentIconPath"
			#Check of the given icon path exists on disk
			elif [ -e "$currentIconPath" ]; then
				report_message "Icon found: $currentIconPath"
			elif [ -e "$BaselineIcons/$currentIconPath" ]; then
				report_message "Icon found: $currentIconPath"
                cp "$BaselineIcons/$currentIconPath" "$BaselineTempIconsDir"/"$currentIconPath"
                chmod 655 "$BaselineTempIconsDir"/"$currentIconPath"
                currentIconPath="$BaselineTempIconsDir/$currentIconPath"
			else
                #If we can't find the local file, report and leave blank
                report_message "ERROR: Icon key cannot be located: $currentIconPath"
                currentIconPath=""
            fi
		else
			#If no icon key is set, ensure it's blank
			report_message "No icon set, leaving blank"
			currentIconPath=""
		fi
        
        #Generate JSON entry for item
        #NOTE: We will strip out the final comma later to ensure a valid JSON
        dialogListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"

        #Done looping. Increase our array value and loop again.
        index=$((index+1))
        progressBarTotal=$((progressBarTotal+1))
    done
}

function process_scripts()
{
# Usage: process_scripts ProfileKey
# Actual use: process_scripts [ InitialScripts | Scripts ]

    #Set an index internal to this function
    currentIndex=0
    #Loop through and test if there is a value in the slot of this index for the given array
    #If this command fails it means we've reached the end of the array in the config file (or there are none) and we exit our loop
    while $pBuddy -c "Print :${1}:${currentIndex}" "$BaselineConfig" > /dev/null 2>&1; do
        #Unset variables for next loop
        unset expectedMD5
        unset actualMD5
        unset currentArguments
        unset currentArgumentArray
        unset currentScript
        unset currentScriptPath
        unset currentDisplayName
        unset scriptDownloadExitCode
        #Get the display name of the label we're installing. We need this to update the dialog list
        currentDisplayName=$($pBuddy -c "Print :${1}:${currentIndex}:DisplayName" "$BaselineConfig")
        #Set the current icon
        if $pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig" > /dev/null 2>&1; then
            currentIconPath=$($pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig")
        fi
        #Set the current script name
        currentScriptPath=$($pBuddy -c "Print :${1}:${currentIndex}:ScriptPath" "$BaselineConfig")
        #Check if the defined script is a remote path
        if [[ ${currentScriptPath:0:4} == "http" ]]; then
            #Set variable to the base file name to be downloaded
            currentScript="$BaselineScripts/"$(basename "$currentScriptPath")
            #Download the remote script, and put it in the Baseline Scripts directory
            curl -s --fail-with-body "${currentScriptPath}" -o "$currentScript"
            #Capture the exit code of our curl command
            scriptDownloadExitCode=$?
            #Check if curl exited cleanly
            if [ "$scriptDownloadExitCode" != 0 ];then
                #Report a failed download
                report_message "ERROR: Script failed to download. Check your URL: $currentScriptPath"
                #Rm the output of our curl command. This will result in it being processed as a failure
                rm_if_exists "$currentScript"
            else
                report_message "Script downloaded successfully: $currentScriptPath"
                #Make our downloaded script executable
                chmod +x "$currentScript"
            fi
        #Check if the given script exists on disk
        elif [ -e "$currentScriptPath" ]; then
            # The path to the script is a local file path which exists
            currentScript="$currentScriptPath"
        elif [ -e "$BaselineScripts/$currentScriptPath" ]; then
            currentScript="$BaselineScripts/$currentScriptPath"
        fi
        #If the currentScript variable still isn't set to an existing file we need to bail..
        if [ ! -e "$currentScript" ]; then
            report_message "ERROR: Script does not exist: $currentScript"
            # Iterate the index up one
            currentIndex=$((currentIndex+1))
            increment_progress_bar
            # Report the fail
            dialog_command "listitem: title: $currentDisplayName, status: fail"
            #failList+=("$currentDisplayName")
            failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
            # Bail this pass through the while loop and continue processing next item
            continue
        fi
        #Check for MD5 validation
        if $pBuddy -c "Print :${1}:${currentIndex}:MD5" "$BaselineConfig" > /dev/null 2>&1; then
            #This script has MD5 validation provided
            #Read the expected MD5 value from the profile
            expectedMD5=$($pBuddy -c "Print :${1}:${currentIndex}:MD5" "$BaselineConfig")
            #Calculate the actual MD5 of the script
            actualMD5=$(md5 -q "$currentScript")
            #Evaluate whether the expected and actual MD5 do not match
            if [ "$actualMD5" != "$expectedMD5" ]; then
                report_message "ERROR: MD5 value mismatch. Expected: $expectedMD5 Actual: $actualMD5"
                # Iterate the index up one
                currentIndex=$((currentIndex+1))
                # Only increment the progress bar if we're processing Scripts, not InitialScripts since users won't see those
                if [ "$1" = "Scripts" ]; then
                    increment_progress_bar
                fi
                # Report the fail
                dialog_command "listitem: title: $currentDisplayName, status: fail"
                #failList+=("$currentDisplayName")
                failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
                # Bail this pass through the while loop and continue processing next item
                continue
            fi
        fi
        #Check if there are Arguments defined, and set the variable accordingly
        if $pBuddy -c "Print :${1}:${currentIndex}:Arguments" "$BaselineConfig" > /dev/null 2>&1; then
            #This script has arguments defined
            currentArguments=$($pBuddy -c "Print :${1}:${currentIndex}:Arguments" "$BaselineConfig")
        else
            #This script does not have arguments defined
            currentArguments=""
        fi
        #Now we have to do a trick in case there are multiple arguments, some of which are quoted together
        #Consider: /path/to/script.sh --font "Times New Roman"
        #Used the eval trick outlined here: https://superuser.com/questions/1066455/how-to-split-a-string-with-quotes-like-command-arguments-in-bash
        currentArgumentArray=()
        if [ -n "$currentArguments" ]; then
            eval 'for argument in '$currentArguments'; do currentArgumentArray+=$argument; done'
        fi

        #Update the dialog window so that this item shows as "pending"
        dialog_command "listitem: title: $currentDisplayName, status: wait"

        #Only set the progress label if we're processing Scripts, not InitialScripts since users won't see those
        if [ "$1" = "Scripts" ]; then
            set_progressbar_text "$currentDisplayName"
        fi

        #Call our script with our desired options. Default options first, so that they can be overriden by "currentArguments"
        "$currentScript" ${currentArgumentArray[@]} >> "$ScriptOutputLog" 2>&1
        scriptExitCode=$?
        if [ $scriptExitCode != 0 ]; then
            report_message "Script failed to complete: $currentScript - Exit Code: $scriptExitCode"
            dialog_command "listitem: title: $currentDisplayName, status: fail"
            #failList+=("$currentDisplayName")
            failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
        else
            report_message "Script completed successfully: $currentScript"
            dialog_command "listitem: title: $currentDisplayName, status: success"
            successList+=("$currentDisplayName")
       fi

       #Iterate index for next loop
        currentIndex=$((currentIndex+1))

        #Only increment the progress bar if we're processing Scripts, not InitialScripts since users won't see those
        if [ "$1" = "Scripts" ]; then
            increment_progress_bar
        fi
    done
}

function build_pkg_arrays()
{
    #Set an index internal to this function
    index=0
    #Loop through and test if there is a value in the slot of this index for the given array
    #If this command fails it means we've reached the end of the array in the config file and we exit our loop

    while $pBuddy -c "Print :Packages:${index}" "$BaselineConfig" > /dev/null 2>&1; do
        #Get the Display Name of the current item
        currentDisplayName=$($pBuddy -c "Print :Packages:${index}:DisplayName" "$BaselineConfig")
        dialogList+="$currentDisplayName"
        #Done looping. Increase our array value and loop again.
        index=$((index+1))
    done
}

function process_pkgs()
{
    #Set an index internal to this function
    currentIndex=0
    #Loop through and test if there is a value in the slot of this index for the given array
    #If this command fails it means we've reached the end of the array in the config file (or there are none) and we exit our loop
    while $pBuddy -c "Print :Packages:${currentIndex}" "$BaselineConfig" > /dev/null 2>&1; do
        # Unset variables for next loop
        unset currentPKG
        unset currentPKGPath
        unset expectedTeamID
        unset expectedMD5
        unset actualTeamID
        unset actualMD5
        unset currentArguments
        unset currentArgumentArray
        unset currentDisplayName
        unset pkgBasename
        unset downloadResult

        #Get the display name of the label we're installing. We need this to update the dialog list
        currentDisplayName=$($pBuddy -c "Print :Packages:${currentIndex}:DisplayName" "$BaselineConfig")
        #Set the current icon
        if $pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig" > /dev/null 2>&1; then
            currentIconPath=$($pBuddy -c "Print :$configKey:${index}:Icon" "$BaselineConfig")
        fi
        #Set the current package path
        currentPKGPath=$($pBuddy -c "Print :Packages:${currentIndex}:PackagePath" "$BaselineConfig")
        
        ##Here is where we begin checking what kind of PKG was defined, and how to process it
        ##The end result of this chunk of code, is that we have a valid path to a PKG on the file system
        ##Else we bail and continue looping to install the next item

        #Check if the package path is a web URL
        if [[ ${currentPKGPath:0:4} == "http" ]]; then
            # The path to the PKG appears to be a URL.
            #^^^ CHANGE STUFF HERE ^^^#
            #Get the basename of the .pkg we're downloading
            pkgBasename=$(basename "$currentPKGPath")
            #Set the "currentPKG" variable, this gets used as the download path as well as processed later
            currentPKG="$BaselinePackages"/"$pkgBasename"
            #Check for conflict. If there's already a PKG in the directory we're downloading to, delete it
            rm_if_exists "$currentPKG"
            #Perform the download of the remote pkg
            curl -LJs "$currentPKGPath" -o "$currentPKG"
            #Capture the output of our curl command
            downloadResult=$?
            #Verify curl exited with 0
            if [ "$downloadResult" != 0 ]; then
                report_message "ERROR: PKG failed to download: $currentPKGPath"
                # Iterate the index up one
                currentIndex=$((currentIndex+1))
                increment_progress_bar
                # Report the fail
                dialog_command "listitem: title: $currentDisplayName, status: fail"
                # Bail this pass through the while loop and continue processing next item
                continue
            else
                debug_message "PKG downloaded successfully: $currentPKGPath downloaded to $currentPKG"
            fi
        fi
        
        # Check if the pkg exists
        if [ -e "$currentPKG" ]; then
            debug_message "PKG found: $currentPKG"
        elif [ -e "$currentPKGPath" ]; then
            # The path to the PKG appears to exist on the local file system
            currentPKG="$currentPKGPath"
        elif [ -e "$BaselinePackages/$currentPKGPath" ]; then
            # The path to the PKG appears to exist within Baseline directory
            currentPKG="$BaselinePackages/$currentPKGPath"
        else
            report_message "Package not found $currentPKGPath"
            dialog_command "listitem: title: $currentDisplayName, status: fail"
            #failList+=("$currentDisplayName")
            failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
            currentIndex=$((currentIndex+1))
            increment_progress_bar
            continue
        fi

        ##At this point, the pkg exists on the file system, or we've bailed on this loop.

        #Check if there are Arguments defined, and set the variable accordingly
        if $pBuddy -c "Print :Packages:${currentIndex}:Arguments" "$BaselineConfig" > /dev/null 2>&1; then 
            #This pkg has arguments defined
            currentArguments=$($pBuddy -c "Print :Packages:${currentIndex}:Arguments" "$BaselineConfig")
        else
            #This pkg does not have arguments defined
            currentArguments=""
        fi
        #Now we have to do a trick in case there are multiple arguments, some of which are quoted together
        #Consider: /path/to/script.sh --font "Times New Roman"
        #Used the eval trick outlined here: https://superuser.com/questions/1066455/how-to-split-a-string-with-quotes-like-command-arguments-in-bash
        currentArgumentArray=()
        eval 'for argument in '$currentArguments'; do currentArgumentArray+=$argument; done'

        if $pBuddy -c "Print :Packages:${currentIndex}:TeamID" "$BaselineConfig" > /dev/null 2>&1; then
            #This pkg has TeamID defined
            expectedTeamID=$($pBuddy -c "Print :Packages:${currentIndex}:TeamID" "$BaselineConfig")
        else
            #This pkg does not have TeamID Validation defined
            expectedTeamID=""
        fi
        if $pBuddy -c "Print :Packages:${currentIndex}:MD5" "$BaselineConfig" > /dev/null 2>&1; then
            #This script has MD5 defined
            expectedMD5=$($pBuddy -c "Print :Packages:${currentIndex}:MD5" "$BaselineConfig")
        else
            #This script does not have MD5 defined
            expectedMD5=""
        fi
        #Update the dialog window so that this item shows as "pending"
        dialog_command "listitem: title: $currentDisplayName, status: wait"
        set_progressbar_text "$currentDisplayName"

        ## Package validation happens here
        # Check TeamID, if a value has been provided
        if [ -n "$expectedTeamID" ]; then
            #Get the TeamID for the current PKG
            actualTeamID=$(spctl -a -vv -t install "$currentPKG" 2>&1 | awk -F '(' '/origin=/ {print $2 }' | tr -d ')' )
            # Check if actual does not match expected
            if [ "$expectedTeamID" != "$actualTeamID" ]; then
                report_message "TeamID validation of PKG failed: $currentPKG - Expected: $expectedTeamID Actual: $actualTeamID"
                dialog_command "listitem: title: $currentDisplayName, status: fail"
                #failList+=("$currentDisplayName")
                failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
                # Iterate the index up one
                currentIndex=$((currentIndex+1))
                increment_progress_bar
                # Report the fail
                dialog_command "listitem: title: $currentDisplayName, status: fail"
                # Bail this pass through the while loop and continue processing next item
                continue
            else
                report_message "TeamID of PKG validated: $currentPKG $expectedTeamID"
            fi
        fi
        
        # Check MD5, if a value has been provided
        if [ -n "$expectedMD5" ]; then
            #Get MD5 for the current PKG
            actualMD5=$(md5 -q "$currentPKG")
            # Check if actual does not match expected
            if [ "$expectedMD5" != "$actualMD5" ]; then
                report_message "MD5 validation of PKG failed: $currentPKG - Expected: $expectedMD5 Actual: $actualMD5"
                dialog_command "listitem: title: $currentDisplayName, status: fail"
                #failList+=("$currentDisplayName")
                failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
                # Iterate the index up one
                currentIndex=$((currentIndex+1))
                increment_progress_bar
                # Report the fail
                dialog_command "listitem: title: $currentDisplayName, status: fail"
                # Bail this pass through the while loop and continue processing next item
                continue
            else
                report_message "MD5 of PKG validated: $currentPKG $expectedMD5"
            fi
        fi

        ## The package installation happens here. We do this in a variable so we can capture the output and report it for debugging
	    pkgInstallerOutput=$(installer -allowUntrusted -pkg "$currentPKG" -target / ${currentArgumentArray[@]} )
        # Capture the installer exit code
        pkgExitCode=$?
        # Verify the install completed successfully
        if [ $pkgExitCode != 0 ]; then
            report_message "Package failed to complete: $currentPKG - Exit Code: $pkgExitCode"
            dialog_command "listitem: title: $currentDisplayName, status: fail"
            #failList+=("$currentDisplayName")
            failListJson+="{\"title\" : \"$currentDisplayName\", \"icon\" : \"$currentIconPath\", \"status\" : \"\"},"
        else
            report_message "Package completed successfully: $currentPKG"
            dialog_command "listitem: title: $currentDisplayName, status: success"
            successList+=("$currentDisplayName")
        fi
        debug_message "Output of the install package command: $pkgInstallerOutput"
        # Iterate to the next index item, and continue our loop
        currentIndex=$((currentIndex+1))
        increment_progress_bar
    done
}

function build_dialog_json_file()
{
    jsonFile="$1"
    jsonList="$2"
    # Initiate Json file
    /bin/echo "{\"listitem\" : [" >> $jsonFile
    # For each item in our list, add the Json line
    for jsonItem in $jsonList; do
        /bin/echo "$jsonItem" >> $jsonFile
    done
    # This trick removes the final character from the file, to ensure a valid Json
    cat $jsonFile | sed '$ s/.$//' > /var/tmp/tempJson
    mv /var/tmp/tempJson $jsonFile
    # Finish Json file
    /bin/echo "]}" >> $jsonFile

    # Set global read permissions for Json file
    chmod 644 "$jsonFile"

    # Set global read permissions for Icon directory
    chmod 655 "$BaselineTempIconsDir"
}

function build_dialog_list_options()
{
    # This function populates an array with all of the items Baseline iterates through
    for i in $dialogList; do
        dialogListItems+=(--listitem $i)
    done
}

function check_exit_condition()
{
    exitConditionPath=""
    # If `ExitCondition` key is passed in the configuration profile, then set a variable
    if $pBuddy -c "Print :ExitCondition" "$BaselineConfig" > /dev/null 2>&1; then
        exitConditionPath=$($pBuddy -c "Print :ExitCondition" "$BaselineConfig" | sed 's/"//g' )
    fi
    # If our variable is set, and if the file exists, cleanup and exit quietly
    if [ -n "$exitConditionPath" ] && [ -e "$exitConditionPath" ]; then
        cleanup_and_exit "Exit Condition exists. Exiting: "$exitConditionPath""
    fi

}

function check_restart_option()
{
    # Set variable for whether or not we'll force a restart. Defaults to 'true'
    forceRestartSetting=$($pBuddy -c "Print :Restart" "$BaselineConfig")

    if  [ $forceRestartSetting = "false" ]; then
        forceRestart="false"
    else
        forceRestart="true"
    fi

    logoutSetting=$($pBuddy -c "Print :LogOut" "$BaselineConfig")
    if  [ $logoutSetting = "true" ]; then
        forceLogOut="true"
    else
        forceLogOut="false"
    fi

}

function check_progress_options()
{
    # Set variable for whether or not we'll display a progress bar. Defaults to 'false'
    showProgressBarSetting=$($pBuddy -c "Print :ProgressBar" "$BaselineConfig")

    if  [ $showProgressBarSetting = "true" ]; then
        showProgressBar="true"
    else
        showProgressBar="false"
    fi

    # Set variable for whether or not we'll display a progress bar label. Defaults to 'false'
    showProgressBarDisplayNameSetting=$($pBuddy -c "Print :ProgressBarDisplayNames" "$BaselineConfig")

    if  [ $showProgressBarDisplayNameSetting = "true" ]; then
        progressBarDisplayNames="true"
    else
        progressBarDisplayNames="false"
    fi
}

function increment_progress_bar()
{
    # If we're not displaying the progress bar, skip
    if [ "$showProgressBar" != "true" ]; then
        return
    fi

    # Increment progress bar
    progressBarValue=$((progressBarValue+1))
    # Do the math to determine total progress bar size for real increment
    progressBarPercentage=$((progressBarValue*100/progressBarTotal))
    
    dialog_command "progress: $progressBarPercentage"
}

function set_progressbar_text()
{
    # If we're not displaying the progress bar, skip
    if [ "$progressBarDisplayNames" != "true" ]; then
        return
    fi

    dialog_command "progresstext: $1"
}

#############################################
#   Configure Default Installomator Options #
#############################################

defaultInstallomatorOptions=(
    BLOCKING_PROCESS_ACTION=kill
    NOTIFY=silent
)

if [ "$dryRun" = true ]; then
    defaultInstallomatorOptions+="DEBUG=2"
fi

########################################################################################################
########################################################################################################
##
##      SCRIPT STARTS HERE
##
########################################################################################################
########################################################################################################
debug_message "Starting script actions"

#Verify we're running as root
check_root

#Check if exit condition has been defined
check_exit_condition

#No falling asleep on the job, bud
no_sleeping

#Set trap so that things always exit cleanly
trap cleanup_and_exit 1 2 3 6

#Check if directories for Packages and Scripts exist already.
#This is useful for testing, or if running the script directly (not the pkg)
make_directory "$BaselineScripts"
make_directory "$BaselinePackages"

#Initiate Logging
initiate_logging

#Setup report
initiate_report

#############################################
#   Verify a Configuration File is in Place #
#############################################
verify_configuration_file

###########################
#   Install Installomator #
###########################
#If Installomator is going to be used, install it now
if $pBuddy -c "Print :Installomator:0" "$BaselineConfig" > /dev/null 2>&1; then
    install_installomator
fi

#########################
#   Install SwiftDialog #
#########################
install_dialog
#If swiftDialog still isn't installed, exit with an error
if [ ! -e "$dialogAppPath" ]; then
    cleanup_and_exit 1 "ERROR: SwiftDialog failed to install after numerous attempts. Exiting."
fi

#############################################
#   Wait until a user is verified logged in #
#############################################
wait_for_user

# Get the currently logged in user home folder and UID
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
currentUserUID=$(/usr/bin/id -u "$currentUser")
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)

#############
#   Arrays  #
#############

# Initiate arrays
dialogList=()
dialogListItems=()
dialogListJson=()
failList=()
failListJson=()
successList=()

installomatorLabels=()
installomatorOptions=()

scriptsToProcess=()
scriptArguments=()

pkgsToInstall=()
pkgValidations=()

######################
# Integers and Bools #
######################

# Initiate integers
progressBarValue=0
progressBarTotal=0

# Initiate bools
showProgressBar="false"
progressBarDisplayNames="false"

##############################
#   Process Initial Scripts  #
##############################

process_scripts InitialScripts

#Check if a custom plist was delivered/altered during InitialScripts
check_for_custom_plist

#We check for Installomator again, to support custom plist swapping
if $pBuddy -c "Print :Installomator:0" "$BaselineConfig" > /dev/null 2>&1; then
    install_installomator
fi

#######################
#   Customizations    #
#######################
# Check if we are going to restart. This has to be here, because the Dialog customizations depend on it
check_restart_option

# Check if we should display a progress bar under the UI
check_progress_options


######################################
#   Configure List Customizations    #
######################################

finalListCommand=()
finalListCommand+="$dialogPath"
finalListCommand+="--blurscreen"
finalListCommand+="--button1disabled"

# Read the Dialog List Arguments customizations, if there are any
if $pBuddy -c "Print DialogListOptions" "$BaselineConfig" > /dev/null 2>&1; then
    dialogListArguments=$($pBuddy -c "Print DialogListOptions" "$BaselineConfig")
fi

# If we found customizations, read them into our final list command array
if [ -n "$dialogListArguments" ]; then
    eval 'for customization in '$dialogListArguments'; do finalListCommand+=$customization; done'
fi

# This function is not with the rest, but it makes the most sense as I add on this feature.
# I also don't know how to set the variable by passing the name of that variable as an argument to the function.
# So I'll have to define this function several times.
# I grow old … I grow old …I shall wear the bottoms of my trousers rolled..
function configure_dialog_list_arguments()
{
    # $1 is the SwiftDialog option to change, $2 is the default value for that option if its not included in the profile
    if (($dialogListArguments[(Ie)$1])); then
        # $1 was included in the customization, so we report it and move along
        log_message "Dialog List Customization Found: $1"
    else
        # $1 wasn't included in the customization options, so we'll set the default value
        finalListCommand+="$1"
        finalListCommand+="$2"
    fi
}

# Adjust language of our list view window depending on whether or not the device will restart/logout
defaultListMessage="Feel free to step away, this could take 30 minutes or more."
if $forceLogOut; then
    # Add a line break and a sentence about logging out
    defaultListMessage+="\n\nYou will be logged out when it's ready for use."
elif $forceRestart; then
    # Add a line break and a sentence about restarting.
    defaultListMessage+="\n\nYour computer will restart when it's ready for use." 
fi

configure_dialog_list_arguments "--title" "Your computer setup is underway"
configure_dialog_list_arguments "--message" "$defaultListMessage"
configure_dialog_list_arguments "--icon" "/System/Library/CoreServices/KeyboardSetupAssistant.app/Contents/Resources/AppIcon.icns"
configure_dialog_list_arguments "--width" 900
configure_dialog_list_arguments "--height" 550
configure_dialog_list_arguments "--quitkey" ']'

if [ "$showProgressBar" = "true" ]; then
    configure_dialog_list_arguments "--progress"
fi

if [ "$progressBarDisplayNames" = "true" ]; then
    configure_dialog_list_arguments "--progresstext" ' '
fi


#########################################
#   Configure Success Customizations    #
#########################################

finalSuccessCommand=()
finalSuccessCommand+="$dialogPath"
finalSuccessCommand+="--blurscreen"

# Read the Dialog Success Arguments customizations, if there are any
if $pBuddy -c "Print DialogSuccessOptions" "$BaselineConfig" > /dev/null 2>&1; then
    dialogSuccessArguments=$($pBuddy -c "Print DialogSuccessOptions" "$BaselineConfig")
fi

# If we found customizations, read them into our final list command array
if [ -n "$dialogSuccessArguments" ]; then
    eval 'for customization in '$dialogSuccessArguments'; do finalSuccessCommand+=$customization; done'
fi

function configure_dialog_success_arguments()
{
    # $1 is the SwiftDialog option to change, $2 is the default value for that option if its not included in the profile
    if (($dialogSuccessArguments[(Ie)$1])); then
        # $1 was included in the customization, so we report it and move along
        log_message "Dialog Success Customization Found: $1"
    else
        # $1 wasn't included in the customization options, so we'll set the default value
        finalSuccessCommand+="$1"
        finalSuccessCommand+="$2"
    fi
}

configure_dialog_success_arguments "--title" "Your computer setup is complete"
configure_dialog_success_arguments "--icon" "/System/Library/CoreServices/KeyboardSetupAssistant.app/Contents/Resources/AppIcon.icns"

# Different values for --message and --button1text if we're forcing log out or restart
if $forceLogOut; then
    configure_dialog_success_arguments "--message" "You must log out before you can begin using your computer."
    configure_dialog_success_arguments "--button1text" "Log Out Now"
    configure_dialog_success_arguments "--timer" "120"
fi

if $forceRestart; then
    configure_dialog_success_arguments "--message" "Your device needs to restart before you can begin use."
    configure_dialog_success_arguments "--button1text" "Restart Now"
    configure_dialog_success_arguments "--timer" "120"
else
    configure_dialog_success_arguments "--message" "Your device is ready for you."
fi


#########################################
#   Configure Failure Customizations    #
#########################################

finalFailureCommand=()
finalFailureCommand+="$dialogPath"
finalFailureCommand+="--blurscreen"

# Read the Dialog Failure Arguments customizations, if there are any
if $pBuddy -c "Print DialogFailureOptions" "$BaselineConfig" > /dev/null 2>&1; then
    dialogFailureArguments=$($pBuddy -c "Print DialogFailureOptions" "$BaselineConfig")
fi

# If we found customizations, read them into our final list command array
if [ -n "$dialogFailureArguments" ]; then
    eval 'for customization in '$dialogFailureArguments'; do finalFailureCommand+=$customization; done'
fi

function configure_dialog_failure_arguments()
{
    # $1 is the SwiftDialog option to change, $2 is the default value for that option if its not included in the profile
    if (($dialogFailureArguments[(Ie)$1])); then
        # $1 was included in the customization, so we report it and move along
        log_message "Dialog Failure Customization Found: $1"
    else
        # $1 wasn't included in the customization options, so we'll set the default value
        finalFailureCommand+="$1"
        finalFailureCommand+="$2"
    fi
}

configure_dialog_failure_arguments "--title" "Your computer setup is complete"
configure_dialog_failure_arguments "--icon" "/System/Library/CoreServices/KeyboardSetupAssistant.app/Contents/Resources/AppIcon.icns"
configure_dialog_failure_arguments "--message" "Your computer setup is complete, however not everything was installed as expected. Review the list below, and contact IT if you need assistance."

# Different values for --message and --button1text if we're forcing log out or restart
if $forceLogOut; then
    configure_dialog_failure_arguments "--button1text" "Log Out Now"
    configure_dialog_failure_arguments "--timer" "120"
fi

if $forceRestart; then
    configure_dialog_failure_arguments "--button1text" "Restart Now"
    configure_dialog_failure_arguments "--timer" "120"
fi


###################
#   Build Arrays  #
###################
# Build dialogList array by reading our configuration and looping through things

build_dialog_array Installomator
build_dialog_array Packages
build_dialog_array Scripts
build_dialog_json_file "$dialogJsonFile" "$dialogListJson"
build_dialog_list_options


##################################
#   Draw our dialog list window  #
##################################

#Create our initial Dialog Window. Do this in an "until" loop, and attempts 10 times before exiting in case it fails to launch for some reason
dialogAttemptCount=1
until pgrep -q -x "Dialog"; do
    if [ "$dialogAttemptCount" -le 10 ]; then
        ${finalListCommand[@]} \
        --commandfile "$dialogCommandFile" \
        --jsonfile "$dialogJsonFile" \
        & sleep 1
        dialogAttemptCount=$(( dialogAttemptCount +1 ))
    else
        cleanup_and_exit 1 "**WARNING** SwiftDialog failed to launch after 10 attempts. This likely indicates an issue with the options in the configuration file. Check your file paths."
    fi
done

#########################
#   Install the things  #
#########################

# Progress Bar will be pulsing until a value is set
if [ "$showProgressBar" = "true" ]; then
    dialog_command "progress: 1"
fi

process_installomator_labels

process_pkgs

process_scripts Scripts

#Check if we have a custom Dialog.app icon waiting to process. If yes, reinstall dialog
if [ -e "/Library/Application Support/Dialog/Dialog.png" ]; then
    dialog_command "listitem: add, title: Finishing up"
    dialog_command "listitem: Finishing up: wait"
    rm_if_exists "$dialogAppPath"
    install_dialog
    dialog_command "listitem: Finishing up: success"
fi

if [ "$dryRun" = true ]; then
    sleep 5
fi

#Close our running dialog window
dialog_command "quit:"

#Do final script swiftDialog stuff
#If the failList is empty, this means success
if [ -z "$failListJson" ]; then
    #Create our Success Dialog Window. We use a "while" loop and a nested if/then in order to bail if there's a configuration file problem.
    #Set a timer for our attempts
    dialogAttemptCount=1
    #Set our exit variable for the while loop
    dialogCompletionWindow="incomplete"
    #Set our exit condition for the while loop
    while [ $dialogCompletionWindow = "incomplete" ]; do
        #If we haven't tried 10 times yet, then try to call Dialog
        if [ "$dialogAttemptCount" -le 10 ]; then
            #If dialog exits 0, then exit our loop
            ${finalSuccessCommand[@]}
            dialogExitCode=$?
            if [ $dialogExitCode = 0 ] || [ $dialogExitCode = 4 ]; then
                dialogCompletionWindow="complete"
            fi
            #Increment our dialog attempt count
            sleep 1
            dialogAttemptCount=$(( dialogAttemptCount +1 ))
        else
            #If we got here, dialog tried 10 times and never opened properly. Exit with a message to the log file.
            cleanup_and_exit 1 "**WARNING** SwiftDialog failed to launch after 10 attempts. This likely indicates an issue with the options in the configuration file. Check your file paths."
        fi
    done

    # We are done!
    cleanup_and_restart
else
    #There was at least one failed item. Build fail list
    # failListItems=()
    # for i in ${failList[@]}; do
    #     failListItems+=(--listitem $i)
    # done
    build_dialog_json_file "$dialogFailedJsonFile" "$failListJson"
    #Create our Failure Dialog Window. We use a "while" loop and a nested if/then in order to bail if there's a configuration file problem.
    #Set a timer for our attempts
    dialogAttemptCount=1
    #Set our exit variable for the while loop
    dialogCompletionWindow="incomplete"
    #Set our exit condition for the while loop
    while [ $dialogCompletionWindow = "incomplete" ]; do
        #If we haven't tried 10 times yet, then try to call Dialog
        if [ "$dialogAttemptCount" -le 10 ]; then
            #If dialog exits 0, then exit our loop
            ${finalFailureCommand[@]} --jsonfile "$dialogFailedJsonFile" #${failListItems[@]}
            dialogExitCode=$?
            if [ $dialogExitCode = 0 ] || [ $dialogExitCode = 4 ]; then
                dialogCompletionWindow="complete"
            fi
            #Increment our dialog attempt count
            sleep 1
            dialogAttemptCount=$(( dialogAttemptCount +1 ))
        else
            #If we got here, dialog tried 10 times and never opened properly. Exit with a message to the log file.
            cleanup_and_exit 1 "**WARNING** SwiftDialog failed to launch after 10 attempts. This likely indicates an issue with the options in the configuration file. Check your file paths."
        fi
    done

    # We are done!
    cleanup_and_restart
fi
