#!/data/data/com.termux/files/usr/bin/bash
# FastUpTV - one command setup for the phone.
#
#   bash mobile/install.sh
#
# It installs adb + git, clones the repo, and puts a "FastUpTV" shortcut on your home screen
# (via the Termux:Widget app), so from then on it is one tap.

set -e
say() { printf "  %s\n" "$*"; }

say "1/4  packages (adb + git) ..."
pkg update -y >/dev/null 2>&1 || true
pkg install -y android-tools git >/dev/null

say "2/4  repo ..."
DIR="$HOME/FastUpTV"
if [ -d "$DIR/.git" ]; then
    git -C "$DIR" pull --ff-only >/dev/null 2>&1 || true
else
    git clone --depth 1 https://github.com/dualwarez/FastUpTV.git "$DIR" >/dev/null
fi
say "     $DIR"

say "3/4  home-screen shortcut ..."
mkdir -p "$HOME/.shortcuts"
cat > "$HOME/.shortcuts/FastUpTV-clean.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/FastUpTV" || exit 1
bash mobile/setup.sh
echo
echo "  (band karne ke liye Back dabao)"
read -r _
SH
chmod +x "$HOME/.shortcuts/FastUpTV-clean.sh"

cat > "$HOME/.shortcuts/FastUpTV-restore.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/FastUpTV" || exit 1
bash mobile/restore.sh
echo
read -r _
SH
chmod +x "$HOME/.shortcuts/FastUpTV-restore.sh"

say "4/4  done"
echo
echo "  Ab: F-Droid se 'Termux:Widget' install karo, home screen par long-press >"
echo "  Widgets > Termux:Widget > 'FastUpTV-clean' chuno."
echo "  Uske baad TV clean karna = ek tap."
echo
echo "  Pehli baar: TV par USB debugging ON hona chahiye (Settings > About > Build x7)."
echo
