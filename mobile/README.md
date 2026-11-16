# FastUpTV from your phone (Termux)

No laptop? You can run FastUpTV **from the phone itself**, on the same Wi-Fi as the TV.

## 1. Install Termux

Get it from **F-Droid** (recommended) or the Play Store: <https://f-droid.org/packages/com.termux/>

## 2. Install the tools

Open Termux and paste (one block):

```bash
pkg update -y && pkg install -y android-tools curl git
```

`android-tools` gives you `adb`; `git` is how you get this repo.

## 3. Get FastUpTV

```bash
git clone https://github.com/dualwarez/FastUpTV.git
cd FastUpTV
```

## 4. On the TV (once)

Settings -> About -> press **OK 7 times** on *Build* -> Developer options -> **USB debugging** ON.
Keep the TV on, on the same Wi-Fi as the phone.

## 5. Run it

```bash
bash mobile/setup.sh
```

The script scans your Wi-Fi for the TV, backs it up to `~/fastuptv-backup-<date>/`, disables the
vendor bloat, tunes the system and (if `apk/launcher.apk` is there) installs the new home screen.

## 6. Undo

```bash
bash mobile/restore.sh
```

## Notes

- First connection: the TV may show **"Allow USB debugging?"** - tick *Always allow* and press OK.
- Termux has no root; the script only uses `adb`, exactly like the Windows version. Nothing is
  uninstalled or flashed.
- If the scan finds nothing, connect by hand and run again:
  ```bash
  adb connect 192.168.1.50:5555
  bash mobile/setup.sh
  ```
- The launcher APK must be inside the repo (`apk/launcher.apk`); it is, if you cloned the whole repo.
- This path is newer than the Windows one - if something looks off, open an issue with your TV model.
