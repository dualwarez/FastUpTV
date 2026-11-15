# Credits

FastUpTV is a thin wrapper around other people's work. Thank you:

| What | Licence |
|---|---|
| **Home screen app** (`apk/launcher.apk`) | MIT - full text in `apk/LAUNCHER-LICENSE.txt`; the app is a modified build of an MIT-licensed open-source Android TV launcher, with our weather screensaver and other changes on top |
| **adb** (`tools/platform-tools/`) | Apache 2.0, Android SDK Platform-Tools, Google |
| **Debloat approach** | the Android TV community - `pm disable-user` lists from many public projects |

## What FastUpTV adds

- One `.bat`, no terminal, no AI assistant, no cable
- Wi-Fi discovery and brand auto-detection
- Safety guards in the script itself (core packages, keyboard, setup wizard and the current Home app are
  never touched)
- Backup plus a one-click `restore.bat`
- Weather screensaver that follows real weather and time of day (sun, stars, rain, thunder, snow, haze)
- Per-brand lists that keep working when a vendor ships new bloat

If you own something used here and want different wording, open an issue - it will be changed.
