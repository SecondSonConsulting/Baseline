# Baseline
An MDM agnostic zero touch solution for macOS. 

By leveraging SwiftDialog, Installomator, and original code, Baseline provides an automated way to install applications and run scripts. Configure the bahavior of Baseline via a mobileconfig file. Baseline will install packages, scripts, and Installomator labels as defined in the configuration profile.

## Requirements
- macOS 11 or newer
- An installation PKG for the project. Either the provided PKG or your own.
- A configuration profile defining what Installomator labels, Packages, and/or Scripts you wish to run

## How it Works

### Basics

When the Baseline installation package is run, assets are delivered as well as a LaunchDaemon. The LaunchDaemon calls the primary script `/usr/local/Baseline/Baseline.sh`. This method is used in order to ensure your management tools are not paused waiting for Baseline to complete. 

### Order of Operations

Once the daemon initiates the primary script is run, the following sequence occurs:
1. Verifies a configuration file in the preference doman of `com.secondsonconsulting.baseline` is present on the device.
    1. Baseline will timeout after 10 minutes if a profile cannot be found.
1. If Installomator labels are defined in the mobile configuration profile, then the latest version of Installomator is installed.
1. The latest version of SwiftDialog is installed.
1. Baseline then waits until an active end user is logged in on the device.
    1. This process does not have a timeout and will continue to wait until a user has logged into the device.
1. When a valid user is identified a SwiftDialog progress list will show each item as its processed.
1. Installomator is used to process any labels defined in the configuration profile
1. Any scripts defined in the configuration profile are run.
1. Any packages defined in the configuration profile are run.
1. If a custom app icon has been configured for SwiftDialog, then it will be reinstalled in order to pickup this icon.
1. Baseline deletes the LaunchDaemon, so that it is not loaded again after a restart.
1. The entire directory `/usr/local/Baseline` is deleted.
1. The user is presented with a simple message indicating whether everything went smoothly or if there were errors. This message has a timer (default 30 seconds for success, 5 minutes if any items had an error.)
1. After the timer the device forcibly restarts via `shutdown -r now`

### Additional Info

Baseline uses the `--blurscreen` SwiftDialog feature to prevent user access during the setup process. There is an optional "escape" key to close the Dialog windows using `CMD+]`. Using this escape key does not stop Baseline from running, it simply closes the Dialog window. 

## How to Initiate it
Baseline was designed to be run in any way you may need:
- Install the package during automated device enrollment or any other trigger you see fit
- Guide your users to run the package via Self-Service
- Run it manually like any other package

## Files and Folders
Baseline assets are installed in the following directory: `/usr/local/Baseline`

Within the Baseline folder are the following:
- `Packages/`
- `Scripts/`
- `Baseline.sh`

The installation package also installs and loads a LaunchDaemon: `/Library/LaunchDaemons/com.secondsonconsulting.baseline.plist`

Baseline logs can be found at `/var/log/Baseline/Baseline.log`
The full script output can be found at `/var/log/Baseline/DaemonOutput.log`

## Self-Destructing
Upon completion, Baseline deletes the following files and folders
- `/usr/local/Baseline`
- `/Library/LaunchDaemons/com.secondsonconsulting.baseline.plist`

The only files which will be left behind are logs.

## Defining Installomator Labels
Required arguments for an Installomator label:
- `<`
