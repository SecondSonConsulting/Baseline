# Baseline
An MDM agnostic zero touch solution for macOS. 

By leveraging SwiftDialog, Installomator, and original code, Baseline provides an automated way to install applications and run scripts. Configure the bahavior of Baseline via a mobileconfig file. Baseline will install packages, scripts, and Installomator labels as defined in the configuration profile.

## Requirements
- macOS 11 or newer
- A signed installation PKG for the project. Either the provided PKG or your own.
- A configuration profile defining what Installomator labels, Packages, or Scripts you wish to run

## How it Works
When the Baseline installation package is run, assets are delivered as well as a LaunchDaemon. The LaunchDaemon calls the primary script `/usr/local/Baseline/Baseline.sh`. The LaunchDaemon is used in order to ensure your management tools are not paused waiting for the enrollment process to complete. 

Once the daemon initiates the primary script is run, the following sequence occurs:
1. Verifies a configuration file in the preference doman of `com.secondsonconsulting.baseline` is present on the device.
    1. Baseline will timeout after 10 minutes if a profile cannot be found.
1. If Installomator labels are defined in the mobile configuration profile, then the latest version of Installomator is installed.
1. The latest version of SwiftDialog is installed.
1. Baseline then waits until an active end user is logged in on the device.
    1. This process does not have a timeout, it will continue to wait until a user has logged into the device.
1. Once a valid user is identified, a SwiftDialog list is drawn showing a list of all items to be processed. This list will be dynamically updated as items are processed.
1. Installomator is used to process any labels defined in the configuration profile
1. Any scripts defined in the configuration profile are run.
    1. At this time, only 1 script argument is supported but support for unlimited arguments should be coming in a future version.
1. Any packages defined in the configuration profile are run. MD5 and/or TeamID verification are supported to validate scripts.
1. If a custom SwiftDialog icon has been added (probably by virtue of a PKG or script processed by Baseline), Baseline will re-install SwiftDialog in order to apply the custom branding icon.
1. Baseline deletes he LaunchDaemon, so that it is not loaded again after a restart.
1. `/usr/local/Baseline` is deleted
1. The user is presented with a simple message indicating whether everything went smoothly or if there were errors. This message has a 30 second timer.
1. After the 30 second timer, the device restarts.

## How to Initiate it
Baseline was designed to be run in a multitude of ways:
- Install the package during automated device enrollment or via any trigger you see fit
- Guide your users to run the package via Self-Service
- Run it manually like any other package

## Files and Folders
Baseline assets are installed in the following directory: `/usr/local/Baseline`

Within the Baseline folder are the following:
- `Packages/`
- `Scripts/`
- `Support/`
- `Baseline.sh`

The installation package also installs and loads a LaunchDaemon: `/Library/LaunchDaemons/com.secondsonconsulting.baseline.plist`

The Baseline log can be found at `/usr/local/Baseline.log`
