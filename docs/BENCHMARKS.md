# Benchmarks - how the numbers were measured

Every number in the README comes from one real TV, measured by hand, several times. Nothing here is
extrapolated from another device.

## Device

| | |
|---|---|
| TV | Xiaomi Mi TV 4A 40" (`MiTV-AXSO0`, *dangal* board) |
| SoC / RAM | Amlogic, 1 GB (1,014,724 kB total) |
| Android | 9 (API 28), firmware `PI.6036` |
| Display mode | 1280x720 |
| Connection | Wi-Fi 2.4 GHz, same LAN as the PC |

## Method

1. `adb shell am force-stop <package>` before every run, then 1.2 s pause.
2. `adb shell am start -W -n <package>/<activity>`; Android prints `TotalTime`.
3. Three runs per app after the change; the median is quoted. The first run after a reboot is
   discarded (cold page cache).
4. For storage and RAM: `df -h /data` and `cat /proc/meminfo` before and after, same session.

## Results

### YouTube cold start

| Run | Before (stock) | After |
|---|---|---|
| 1 | 1522 ms | 1065 ms |
| 2 | 1752 ms (warm) | 944 ms |
| 3 | - | 963 ms |
| **Quoted** | **1522 ms** | **~950 ms** |

After the change the launcher was also disabled from the boot path, so the second run is warm.

### RAM held by vendor software

| | Before | After |
|---|---|---|
| `com.mitv.tvhome.atv` (PatchWall) | 91 MB PSS, running in the background | 0, package disabled |
| `MemAvailable` | 288 MB | 317 MB |

### Storage

| | Before | After |
|---|---|---|
| `/data` used | 2.8 GB / 4.4 GB (65%) | 2.1 GB / 4.4 GB (50%) |

The 700 MB came from `pm trim-caches`, not from uninstalling anything.

## What these numbers do NOT say

- They are **one device**. A 2 GB TV will show a smaller relative gain; a slower eMMC will show more.
- They are **cold starts of YouTube**, not a synthetic benchmark. Netflix on the same TV cold-starts
  in about 2.5 s and was not changed by this tool.
- The launcher itself (470 KB native, no network beyond the optional weather line) is lighter than
  PatchWall, but "lighter" here means ~50 MB PSS versus ~91 MB - not zero.
- No claim is made about brands that have not been tested. See
  [COMPATIBILITY.md](COMPATIBILITY.md).

If you measure your own TV, open a compatibility report with the numbers and the method - the table
gets better for everyone.
