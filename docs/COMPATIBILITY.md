# Compatibility

What is actually tested, by whom, and when. Anything not in the "tested" table runs only the safe
**core** list (`lists/core.txt`) - those packages exist on every Android TV and are safe to disable.

## Tested

| Device | Android | Firmware | Tested on | Verified |
|---|---|---|---|---|
| Xiaomi Mi TV 4A 40" (`MiTV-AXSO0`, codename *dangal*) | 9 (API 28) | `PI.6036` | 2026-11-09, 2026-11-16 | Wi-Fi discovery, backup, 30 packages disabled, launcher installed and set as Home, PatchWall gone, reboot persistence, `restore.bat` re-enabled everything, YouTube cold start 1522 ms -> 950 ms |

## Untested (the safe core list only)

These brands have a list file, but nobody has reported a real device yet - the file contains no
brand-specific packages, so only `lists/core.txt` runs:

| Brand | List file | Status |
|---|---|---|
| Google TV / Chromecast | `lists/google.txt` | template, untested |
| TCL | `lists/tcl.txt` | template, untested |
| Sony BRAVIA | `lists/sony.txt` | template, untested |
| Hisense | `lists/hisense.txt` | template, untested |
| Philips | `lists/philips.txt` | template, untested |
| OnePlus TV | `lists/oneplus.txt` | template, untested |
| Nokia / other | `lists/nokia.txt` | template, untested |

## What "tested" means here

For the Xiaomi above, all of this was checked on the real TV, not on an emulator:

- `setup.bat` found the TV over Wi-Fi and detected brand/model/Android version
- backup folder contained `packages-all.txt`, `packages-disabled.txt`, `props.txt`, settings dumps,
  `home-owner.txt`
- 30 packages ended up `disabled-user`, and the TV booted and ran normally afterwards
- the new launcher started, was set as Home, and survived a reboot
- `restore.bat` re-enabled every package from the backup and put the stock launcher back
- `pm disable-user` was verified per package (`pm list packages -d`), not assumed

## Reporting your TV (makes the table longer)

Open a **Compatibility report** issue with:

- brand, exact model, Android version, firmware build
- which list you used, and what you disabled
- what worked, what broke
- optional: the console output of `setup.bat`

No personal information needed - model + Android version is enough.
