# Baseline
![Baseline-Screenshot](https://github.com/SecondSonConsulting/Baseline/assets/106293503/8fd02b37-431c-48b9-9349-a171329d754b)
An MDM agnostic zero touch or light touch solution for macOS. 

By leveraging swiftDialog, Installomator, and original code, Baseline provides an automated way to install applications and run scripts. Configure the behavior of Baseline via a mobileconfig or plist file. Baseline will install packages, scripts, and Installomator labels as defined in the configuration file.

## Requirements
- macOS 12 or newer*
- An installation PKG for the project. Either the provided PKG or your own.
- A configuration profile defining what Installomator labels, Packages, and/or Scripts you wish to run

_*This requirement is based on the latest version requirements for swiftDialog. Older versions of swiftDialog supported macOS 11, and Baseline can be used with macOS 11 if you deploy an older swiftDialog prior to running Baseline._

## Visit the Wiki
Detailed documentation on how Baseline works and how to configure it can be found in the [wiki](https://github.com/SecondSonConsulting/Baseline/wiki).

## Thank you to the Mac Admins Community
This project wouldn’t be possible without the amazing hard work provided to the Mac Admins community. Bart Reardon, Søren Theilgaard, Armin Briegel, Adam Codega, Dan Snelson, Pico Mitchell, and all of the other amazing people maintaining and testing swiftDialog, Installomator, and other community tools.
We are happy to have the opportunity to give back, and hope other Mac Admins might find this project useful.

Thank you to Drew Diver and Mykola for feature enhancements on this project.

[macos](https://icons8.com/icon/80591/apple-logo) icon by [Icons8](https://icons8.com) used for example.
