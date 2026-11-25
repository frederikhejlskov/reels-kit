#!/usr/bin/env bash
# Renders the README banner (light and dark) from banner.html at 2x.
set -euo pipefail
cd "$(dirname "$0")"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for t in light dark; do
  "$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=1280,400 \
    --virtual-time-budget=5000 --screenshot="$PWD/banner-$t.png" \
    "file://$PWD/banner.html#$t" 2>/dev/null
done
ls -l banner-*.png
