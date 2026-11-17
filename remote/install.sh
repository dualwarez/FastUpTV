#!/usr/bin/env bash
# FastUpTV - one-line installer for macOS, Linux and Termux (Android)
#
#   curl -fsSL https://raw.githubusercontent.com/dualwarez/FastUpTV/main/remote/install.sh | bash
#
# Downloads the latest release, unpacks it to ~/FastUpTV and runs the setup.
set -e

REPO="dualwarez/FastUpTV"
DEST="$HOME/FastUpTV"
TMP="$(mktemp -d)"

say() { printf "  %s\n" "$*"; }

echo
say "FastUpTV installer"
say "------------------------------"

if ! command -v adb >/dev/null 2>&1; then
    echo
    say "adb nahi mila. Pehle ye chalao:"
    if [ -d "/data/data/com.termux" ]; then
        say "  pkg install android-tools unzip"
    elif [ "$(uname)" = "Darwin" ]; then
        say "  brew install android-platform-tools"
    else
        say "  sudo apt install android-tools-adb unzip"
    fi
    exit 1
fi
say "adb: $(command -v adb)"

say "latest release dhoondh rahe hain ..."
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -o 'https://[^"]*FastUpTV-[^"]*\.zip' | head -1)"
if [ -z "$URL" ]; then
    say "release nahi mila: https://github.com/$REPO/releases"
    exit 1
fi
say "$(basename "$URL")"

say "download ..."
curl -fsSL "$URL" -o "$TMP/fastuptv.zip"

say "extract: $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
if command -v unzip >/dev/null 2>&1; then
    unzip -q "$TMP/fastuptv.zip" -d "$DEST"
else
    say "unzip nahi mila - pkg install unzip / brew install unzip"
    exit 1
fi
rm -rf "$TMP"

cd "$DEST"
echo
bash mobile/setup.sh
