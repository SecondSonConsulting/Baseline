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

### How to Initiate it
Baseline was designed to be run in any way you may need:
- Install the package during automated device enrollment or any other trigger you see fit
- Guide your users to run the package via Self-Service
- Run it manually like any other package

### Files and Folders
All files are deleted upon completion, with the exception of the logs.

Baseline assets are installed in the following directory: `/usr/local/Baseline`

Within the Baseline folder are the following:
- `Packages/`
- `Scripts/`
- `Baseline.sh`

The installation package also installs and loads a LaunchDaemon: `/Library/LaunchDaemons/com.secondsonconsulting.baseline.plist`

Baseline logs can be found at `/var/log/Baseline/Baseline.log`
The full script output can be found at `/var/log/Baseline/DaemonOutput.log`

# Configuration Profile
Baseline performs actions based on a configuration profile delivered via MDM or manually installed. The top level keys in the profile are arrays with dictionaries defined beneath them.

## Defining Installomator Labels

By default, Baseline runs Installomator labels with the following arguments:
`BLOCKING_PROCESS_ACTION=kill`

 Required arguments for an Installomator label:
- `<DisplayName>` : The human facing name of this item.
- `<Label>` : The Installomator label

Optional arguments for an Installomator label:
- `<Arguments>` : Additional options/arguments passed to Installomator for this label. These can be simple, or a complete `valuesfromarguments` custom label.

Example Installomator configurations:
```
<key>Installomator</key>
<array>
    <dict>
        <key>DisplayName</key>
        <string>Google Chrome</string>
        <key>Label</key>
        <string>googlechromepkg</string>
    </dict>
    <dict>
        <key>DisplayName</key>
        <string>Microsoft Office 365</string>
        <key>Label</key>
        <string>valuesfromarguments</string>
        <key>Arguments</key>
        <string>"name=desktoppr" "type=pkg" "downloadURL=https://github.com/scriptingosx/desktoppr/releases/download/v0.3/desktoppr-0.3.pkg" "expectedTeamID=JME5BW3F3R"</string>
    </dict>
</array>
```

## Defining Packages
Required arguments for Packages:
- `<DisplayName>` : The human facing name of this item
- `<PackagePath>` : The path to the package to be installed. The path can be defined in three ways
    - The filename of a package you have placed in the `/usr/local/Baseline/Packages` directory. This is useful if you package Baseline yourself and include additional packages.
    - A local file path. Example: `/Library/Application Support/ManagementDirectory/CompanyLogos.pkg`
    - A remote URL hosting a package to be installed: `https://github.com/SecondSonConsulting/Renew/releases/download/v1.0.1/Renew_v1.0.1.pkg`

Optional arguments for Packages:
- `<TeamID>` : Use this to define the expected TeamID of a signed package in order to verify the authenticity.
- `<MD5>` : Use this to define the expected md5 hash to ensure the integrity of your package.
- `<Arguments>` : In the rare cases a .pkg has additional arguments you wish to pass through the `installer` command, you can do so using this key.

## Define Scripts
Required arguments for Scripts:
- `<DisplayName>` : The human facing name of this item
- `<ScriptPath>` : The path to the script to be installed. The path can be defined in three ways
    - The filename of a script you have placed in the `/usr/local/Baseline/Scripts` directory. This is useful if you package Baseline yourself and include additional scripts.
    - A local file path. Example: `/Library/Application Support/ManagementDirectory/UserSetup.sh`
    - A remote URL hosting a script to be run: `https://github.com/SecondSonConsulting/macOS-Scripts/blob/main/sophosInstall.sh`

Optional arguments for Scripts:
- `<MD5>` : Use this to define the expected md5 hash to ensure the integrity of your script.
- `<Arguments>` : Use this to define additional arguments you wish to pass to your script.
```
<key>Scripts</key>
<array>
    <dict>
        <key>DisplayName</key>
        <string>Example Script</string>
        <key>ScriptPath</key>
        <string>https://github.com/SecondSonExampleScript.sh</string>
        <key>Arguments</key>
        <string>--group "Standard Workstations"</string>
        <key>MD5</key>
        <string>e567252z26d6032dd232df75fd3ba500</string>
    </dict>
</array>
```
## Using iMazing Profile Editor
Currently Baseline is not included in the iMazing Profile Editor default repository, when a full release is announced a pull request will be made to make this happen.
For now, you can utilize iMazing by downloading the plist file in the "Profile Manifest" folder of this Github repo and then following the "Simple customization" instructions to get it in place on your workstation: https://imazing.com/guides/imazing-profile-editor-working-with-custom-preference-manifests
## Screenshots
