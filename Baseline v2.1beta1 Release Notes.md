## What's New?
- New Configuration Key for Each Item Type: `Subtitle`
    - Added support for the new subtitle feature in SwiftDialog 2.4+ which allows Subtitles for each line item
- New Boolena Configuration Key: `Silent`
    - Previously only available as a script parameter, now can be used in the configuration profile itself
    - Using `--silent` at the command line overrides the settings in the configuration profile

## Bugs and Housekeeping
- Moved Report file from `/usr/local/Baseline/Baseline-Report.txt` to `/var/log/Baseline-Report.txt`
- Improved logging function and used standard language for logging item progress/details
- Fixed a bug where Baseline would exit when run from Jamf due to Jamf default script
- Added `--no-rcs` to the shebang for Baseline.sh, preinstall, and postinstall scripts
