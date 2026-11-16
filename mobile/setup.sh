#!/data/data/com.termux/files/usr/bin/bash
# FastUpTV for Android (Termux) - the same job as setup.bat, from your phone.
#
#   pkg update && pkg install android-tools curl
#   bash setup.sh
#
# Everything is reversible with restore.sh. Nothing is uninstalled or flashed.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/fastuptv-backup-$STAMP"
RECORD=""
OK_COUNT=0
FAIL_COUNT=0

say()  { printf "  %s\n" "$*"; }
ok()   { printf "      OK   %s\n" "$*"; }
warn() { printf "      !    %s\n" "$*"; }
fail() { printf "      X    %s\n" "$*"; }

echo
echo "  ############################################################"
echo "  #   F a s t U p T V   (phone / Termux)                     #"
echo "  ############################################################"
echo

# ---------- 1. adb ----------
if ! command -v adb >/dev/null 2>&1; then
    fail "adb nahi mila. Chalao:  pkg install android-tools"
    exit 1
fi
ok "adb: $(command -v adb)"

# ---------- 2. TV dhoondo ----------
echo
say "[1] TV dhoondh rahe hain ..."
SERIAL=""
if adb devices | grep -qE '^[^ ]+[[:space:]]+device$'; then
    SERIAL="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
fi
if [ -z "$SERIAL" ]; then
    # local /24 from the phone's own address
    IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
    if [ -n "$IP" ]; then
        SUBNET="${IP%.*}"
        say "scanning $SUBNET.1-254 port 5555 ..."
        for i in $(seq 1 254); do
            (echo > /dev/tcp/$SUBNET.$i/5555) >/dev/null 2>&1 && adb connect "$SUBNET.$i:5555" >/dev/null 2>&1
        done
        SERIAL="$(adb devices | awk '/:5555\tdevice$/{print $1; exit}')"
    fi
fi
if [ -z "$SERIAL" ]; then
    fail "TV nahi mila."
    echo
    echo "  TV par: Settings > About > Build par 7 baar OK > Developer options > USB debugging ON"
    echo "  Phone aur TV ek hi Wi-Fi par hone chahiye."
    echo "  IP pata ho to:  adb connect 192.168.1.50:5555 && bash setup.sh"
    exit 1
fi
ok "mila: $SERIAL"

# ---------- 3. jaankari ----------
say "[2] TV ki jaankari ..."
BRAND="$(adb -s "$SERIAL" shell getprop ro.product.brand | tr -d '\r')"
MODEL="$(adb -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
SDK="$(adb -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')"
HOMEAPP="$(adb -s "$SERIAL" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tr -d '\r' | awk -F/ '/\//{print $1; exit}')"
say "           brand    : $BRAND"
say "           model    : $MODEL"
say "           android  : API $SDK"
say "           home app : $HOMEAPP"

# ---------- 4. backup ----------
say "[3] Backup -> $BACKUP"
mkdir -p "$BACKUP"
adb -s "$SERIAL" shell pm list packages -f > "$BACKUP/packages-all.txt"
adb -s "$SERIAL" shell pm list packages -d > "$BACKUP/packages-disabled.txt"
adb -s "$SERIAL" shell getprop             > "$BACKUP/props.txt"
adb -s "$SERIAL" shell settings list global > "$BACKUP/settings-global.txt" 2>/dev/null
adb -s "$SERIAL" shell settings list secure > "$BACKUP/settings-secure.txt" 2>/dev/null
adb -s "$SERIAL" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME > "$BACKUP/home-owner.txt"
echo "$SERIAL" > "$BACKUP/serial.txt"
RECORD="$BACKUP/disabled.txt"
: > "$RECORD"
ok "backup saved"

# ---------- 5. lists ----------
say "[4] Bloat hata rahe hain ..."
LISTS="$ROOT/lists/core.txt"
LOWER="$(echo "$BRAND $MODEL" | tr '[:upper:]' '[:lower:]')"
for b in xiaomi tcl sony hisense philips oneplus nokia google; do
    case "$LOWER" in
        *"$b"*) [ -f "$ROOT/lists/$b.txt" ] && LISTS="$LISTS $ROOT/lists/$b.txt" ;;
    esac
done

INSTALLED="$(adb -s "$SERIAL" shell pm list packages | tr -d '\r' | sed 's/^package://')"

for list in $LISTS; do
    [ -f "$list" ] || continue
    while IFS= read -r line; do
        pkg="$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')"
        [ -z "$pkg" ] && continue
        case "$pkg" in
            android|com.android.systemui|com.android.settings|com.android.tv.settings|com.android.shell) warn "core, skip: $pkg"; continue ;;
        esac
        case "$pkg" in
            *inputmethod*|*setupwizard*|*setupwraith*) warn "skip: $pkg"; continue ;;
        esac
        [ "$pkg" = "$HOMEAPP" ] && { warn "home owner, skip"; continue; }
        echo "$INSTALLED" | grep -qx "$pkg" || continue
        OUT="$(adb -s "$SERIAL" shell pm disable-user --user 0 "$pkg" | tr -d '\r')"
        case "$OUT" in
            *"new state: disabled"*) ok "$pkg"; OK_COUNT=$((OK_COUNT+1)); echo "$pkg" >> "$RECORD" ;;
            *) fail "$pkg ($OUT)"; FAIL_COUNT=$((FAIL_COUNT+1)) ;;
        esac
    done < "$list"
done

# ---------- 6. tuning ----------
say "[5] Performance tuning"
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$SERIAL" shell settings put global "$k" 0.5 >/dev/null 2>&1
done
ok "animations 0.5x"
adb -s "$SERIAL" shell pm trim-caches 32G >/dev/null 2>&1
ok "cache trim"

# ---------- 7. launcher ----------
say "[6] Fast launcher"
APK="$ROOT/apk/launcher.apk"
if [ -f "$APK" ]; then
    if adb -s "$SERIAL" install -r "$APK" 2>&1 | grep -q Success; then
        ok "launcher install"
        adb -s "$SERIAL" shell cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity >/dev/null 2>&1
        adb -s "$SERIAL" shell am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity >/dev/null 2>&1
        NOW="$(adb -s "$SERIAL" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tr -d '\r')"
        case "$NOW" in
            *gathin*)
                ok "Home ab naya launcher hai"
                if [ -n "$HOMEAPP" ] && [ "$HOMEAPP" != "com.gathin.tvhome" ]; then
                    adb -s "$SERIAL" shell pm disable-user --user 0 "$HOMEAPP" >/dev/null 2>&1
                    echo "$HOMEAPP" >> "$RECORD"
                    ok "purana launcher disable: $HOMEAPP"
                fi
                ;;
            *) warn "Home set nahi hua - purana launcher wapas chalu hai" ;;
        esac
    else
        warn "launcher install nahi hua (apk/launcher.apk check karo)"
    fi
else
    warn "apk/launcher.apk nahi mila - launcher skip"
fi

echo
echo "  ------------------------------------------------------------"
printf "  HO GAYA!  disabled: %s   fail: %s\n" "$OK_COUNT" "$FAIL_COUNT"
echo "  TV par Home dabao."
echo "  Wapas:  bash mobile/restore.sh"
echo "  Backup: $BACKUP"
echo "  ------------------------------------------------------------"
echo
