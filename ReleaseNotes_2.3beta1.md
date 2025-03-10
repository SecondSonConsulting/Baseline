# Baseline v.2.3beta1 Release Notes
Huge thanks to all of the contributors and idea generators from the community, you all make this tool way better than it would be.

Remember that during betas, you can point iMazing Profile Editor at the `ProfileManifest` folder to get the new keys before they're released to the public profile manifest library.

## New Features
- New item type: `FinalScripts`
    - Similar to `InitialScripts`, these items support all of the same configuration keys as `Scripts`
    - `FinalScripts` run after the DialogListView window is closed, and prior to the `Success` or `Failure` dialog
    - The original idea for this feature was to run a script that sends off the Baseline logs/status to a webhook, but it can be used for anything you see fit including another custom Dialog script prior to the completion screen.
    - Thank you to [@keepfacesbeard](https://github.com/keepfacesbeard) for this contribution!
- Scripts, Initial Scripts, Final Scripts, and PKGs can now be validated with `SHA256` checksum, not just `MD5`.
    - These items now have `SHA256` as a configurable key in your configuration file.
- Scripts, Initial Scripts, and Final Scripts can now be configured to run as the logged in user.
    - All Script type items have a boolean for `AsUser` to indicate they should be run as the logged in user.
    - If there is no logged in user, these items will not be run and they will be listed as Failed
    - Another awesome contribution from [@drewdiver](https://github.com/drewdiver), thank you!

## Improvements
- Deprecated and removed the `ReinstallDialog` key entirely.
    - Previously Baseline would reinstall swiftDialog if a custom Dialog icon was found.
    - This is no longer necessary, as swiftDialog now has a built in feature we can call with `--seticon` to make this update directly.
    - If a file is found at `/Library/Application Support/Dialog/Dialog.png` then Baseline will invoke swiftDialog with the `--seticon` option to accomplish the goal.
    - Due to a quirk with macOS, if you are running Baseline.sh from a Terminal or as a child process of another app, that app will require PPPC permission to manipulate the app icon.
        - Users running from the Baseline PKG (which uses LaunchD) or from their MDM script runner do not need to worry about this.
    - Major kudos, as always, to [@bartreardon](https://github.com/bartreardon) for continually improving swiftDialog. This project could not exist without him.
- Baseline is now published under the MIT open-source license.

## Breaking Changes
- `WaitFor` items have been changed in a manner which impacts user experience and possibly impacts functionality
    -  Previously, `WaitFor` items weren't checked until all other items had completed.
    - `WaitFor` items will now be checked off in real-time as file paths are discovered. This should improve the end user experience when used along with tools like Munki or a script which installs multiple items.
    - `WaitFor` items will no longer get the spinny icon for better UI experience.
    - Previously, the `WaitForTimeout` timer would not start until all other items were processed. Now, `WaitForTimeout` will begin as soon as Baseline begins to process items.
    - The default value for `WaitForTimeout` has been doubled from `300` to `600` seconds to help adjust for this change.

## Bug Fixes
- Fixed a bug where Baseline would not launch the ListView window if any other Dialog process was running at the same time.
    - Big thank you to [@k2graham](https://github.com/k2graham) for this fix.
- Fixed an edge case issue with the icons folder permissions