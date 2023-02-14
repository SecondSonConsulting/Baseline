#!/bin/zsh
# Uncomment this for verbose debug
#set -x 

##########
# This is an example script designed to show some of the features of Baseline.
# Written by: Trevor Sysock of Second Son Consulting
# @BigMacAdmin on Github and Slack
#
# In this example, we're making an InitialScript that will prompt the user to choose their 
# department and then rename the computer and put a script in place to be processed by Baseline 
# according to the user's response.
#
# This script assumes you have the following in place:
# - A Baseline configuration file containing this script in the "InitialScripts" section and "DepartmentSetup.sh" in the "Scripts" section.
# - One or more scripts named to match the abbreviation of the department the user chooses.
#   - /usr/local/Baseline/Scripts/
#        - Acct.sh
#        - Sales.sh
#        - Exec.sh
#        - Art.sh
#        - Tech.sh
# - A "default" script in the Baseline Scripts directory name "DepartmentSetup.sh"
#
# When the user chooses a department, the script associated with that department is renamed "DepartmentSetup.sh", and will be processed by Baseline.

#############
# Functions #
#############

# Verify we are running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "ERROR: This script must be run as root **EXITING**"
  exit 1
fi

#############
# Variables #
#############

# Company name or abbreviation used for naming the computer
companyName="Acme"

# Path to SwiftDialog
dialogPath='/usr/local/bin/dialog'

# Path to Baseline Scripts directory
BaselineScripts="/usr/local/Baseline/Scripts"

# Get the shortname of the current user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
# Get the UID of the current user
currentUserUID=$(/usr/bin/id -u "$currentUser")
# Get the Display Name of the current user
currentUserDisplayName=$(id -F "$currentUser")
# Get the First Name of the current user
firstName=$(/usr/bin/id -F "$currentUser"| cut -d ' ' -f 1)

# Setup your welcome experience
welcomeTitle="Help Us Name Your Mac."
welcomeBody="Hi $currentUserDisplayName, lets get your computer setup.\n\n To start, please choose your department."
departmentChoices="Art,Sales,Accounting,Executive,Technician"

######################
# Script Starts Here #
######################

# Call the dialog command and put the results in a variable, so we can check against them afterwards
departmentSelection=$("$dialogPath" \
--title "$welcomeTitle" \
--message "$welcomeBody" \
--selecttitle "Department" \
--ontop \
--blurscreen \
--position top \
--selectvalues "$departmentChoices")

# Set the Department Abbreviation based on user input
case $departmentSelection in

    *'"Department" : "Accounting"'*)
        departmentAbbr="Acct"
        ;;
    *'"Department" : "Sales"'*)
        departmentAbbr="Sales"
        ;;
    *'"Department" : "Executive"'*)
        departmentAbbr="Exec"
        ;;
    *'"Department" : "Art"'*)
        departmentAbbr="Art"
        ;;
    *'"Department" : "Technician"'*)
        departmentAbbr="Tech"
        ;;
esac

# Set the device name variable
finalComputerName="$companyName"-"$departmentAbbr"-"$firstName"

# Name the computer 3 ways
scutil --set ComputerName $finalComputerName
scutil --set HostName "$finalComputerName".shared
scutil --set LocalHostName $finalComputerName

# Check if there is a department script configured. If there is, rename it so that Baseline processes it.
if [ -e "$BaselineScripts"/"$departmentAbbr".sh ]; then
    mv "$BaselineScripts"/"$departmentAbbr".sh "$BaselineScripts"/DepartmentSetup.sh
fi
