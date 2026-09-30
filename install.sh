#!/bin/sh
# Builds the Hyprland preload and links Filyy, its launcher entry and icon into ~/.local.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$here/build"
cc -shared -fPIC -O2 -Wall -o "$here/build/libnosuspend.so" "$here/src/filyy/platform/nosuspend.c" -lwayland-client -ldl
mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps
ln -sf "$here/filyy" ~/.local/bin/filyy
ln -sf "$here/filyy.desktop" ~/.local/share/applications/filyy.desktop
# The ghost icon an earlier install left behind would win over the PNG as the scalable one.
rm -f ~/.local/share/icons/hicolor/scalable/apps/filyy.svg
ln -sf "$here/assets/filyy.png" ~/.local/share/icons/hicolor/256x256/apps/filyy.png
update-desktop-database ~/.local/share/applications 2>/dev/null || true
gtk-update-icon-cache -q -t ~/.local/share/icons/hicolor 2>/dev/null || true
echo "filyy installiert"
