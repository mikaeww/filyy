#!/bin/sh
# Links Filyy into ~/.local so it starts as `filyy`, from the launcher and with its icon.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$here/build"
cc -shared -fPIC -O2 -Wall -o "$here/build/libnosuspend.so" "$here/nosuspend.c" -lwayland-client -ldl
mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/scalable/apps
ln -sf "$here/filyy.py" ~/.local/bin/filyy
ln -sf "$here/filyy.desktop" ~/.local/share/applications/filyy.desktop
ln -sf "$here/assets/filyy.svg" ~/.local/share/icons/hicolor/scalable/apps/filyy.svg
update-desktop-database ~/.local/share/applications 2>/dev/null || true
gtk-update-icon-cache -q -t ~/.local/share/icons/hicolor 2>/dev/null || true
echo "filyy installiert"
