# FastUpTV from your phone (Termux)

No laptop, no cable. The phone talks ADB to the TV over the same Wi-Fi.

## One command

Open Termux (install it from **F-Droid**) and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/dualwarez/FastUpTV/main/mobile/install.sh | bash
```

Or, if you already have the repo:

```bash
bash mobile/install.sh
```

That installs `android-tools` + `git`, clones the repo to `~/FastUpTV`, and creates two shortcuts.

## One tap after that

1. Install **Termux:Widget** (F-Droid)
2. Long-press your home screen -> Widgets -> Termux:Widget -> **FastUpTV-clean**

Now cleaning a TV is one tap. There is a **FastUpTV-restore** shortcut too.

## First run

1. TV: Settings -> About -> press **OK 7 times** on *Build* -> Developer options -> **USB debugging** ON
2. Phone and TV on the same Wi-Fi
3. Tap the shortcut

The TV shows **"Allow USB debugging?"** - tick *Always allow* and press OK. The script then finds the
TV, backs it up to `~/fastuptv-backup-<date>/`, disables the bloat, tunes it and installs the home
screen.

## Undo

```bash
bash mobile/restore.sh
```
(or the restore shortcut)

## What this is not

This is the same script as the Windows version, run in a terminal. It is not a native app: there is
no graphical plan screen, no per-app checkboxes, no watchdog. If you want that, the Windows tool plus
the `-DryRun` flag gives you the plan; on the phone you get the same logic with less UI.

## Notes

- Termux has no root; only `adb` is used. Nothing is uninstalled or flashed.
- If the scan finds nothing, connect by hand and run again:
  ```bash
  adb connect 192.168.1.50:5555
  bash mobile/setup.sh
  ```
- The launcher APK must be in the repo (`apk/launcher.apk`) - it is, if you cloned the whole repo.
- Android 9 or newer on the phone (that is where Termux's `android-tools` package works well).
