#!/data/data/com.termux/files/usr/bin/bash
# FastUpTV restore (Termux) - turns everything from the last backup back on.
set -u

LATEST="$(ls -d "$HOME"/fastuptv-backup-* 2>/dev/null | sort | tail -1)"
if [ -z "$LATEST" ]; then
    echo "  koi backup nahi mila (~/fastuptv-backup-*)"
    exit 1
fi

SERIAL="$(cat "$LATEST/serial.txt" 2>/dev/null)"
if [ -z "$SERIAL" ]; then
    SERIAL="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
fi
if [ -z "$SERIAL" ]; then
    echo "  TV nahi mila - adb connect <ip>:5555 karo"
    exit 1
fi

echo "  backup: $LATEST"
echo "  TV    : $SERIAL"

OK=0
FAIL=0
while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    OUT="$(adb -s "$SERIAL" shell pm enable --user 0 "$pkg" | tr -d '\r')"
    case "$OUT" in
        *"new state: enabled"*) echo "      OK   $pkg"; OK=$((OK+1)) ;;
        *) echo "      X    $pkg ($OUT)"; FAIL=$((FAIL+1)) ;;
    esac
done < "$LATEST/disabled.txt"

for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$SERIAL" shell settings put global "$k" 1.0 >/dev/null 2>&1
done

STOCK="$(awk -F/ '/\//{print $1; exit}' "$LATEST/home-owner.txt" 2>/dev/null)"
if [ -n "$STOCK" ]; then
    adb -s "$SERIAL" shell pm enable --user 0 "$STOCK" >/dev/null 2>&1
    adb -s "$SERIAL" shell cmd package set-home-activity --user 0 "$STOCK/.MainActivity" >/dev/null 2>&1
    echo "      purana home: $STOCK"
fi
adb -s "$SERIAL" shell pm disable-user --user 0 com.gathin.tvhome >/dev/null 2>&1

echo
echo "  RESTORE HO GAYA - $OK chalu, $FAIL fail"
echo "  TV restart karo."
