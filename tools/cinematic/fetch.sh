#!/bin/bash
# Saves one reel, picture and sound, from the video addresses its page
# loaded (tools/cinematic/video-list.js lists them). The addresses may sit
# in any text: one per line, or quoted with \n between them.
# Usage: .tools/run bash tools/cinematic/fetch.sh <addresses file> <out.mp4>
set -u
list="${1:-}"; out="${2:-}"
if [ ! -s "$list" ] || [ -z "$out" ]; then
  echo "Give a file of video addresses and a file to save: fetch.sh <addresses> <out.mp4>"
  exit 2
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
n=0
while IFS= read -r u; do
  n=$((n + 1))
  code="$(curl -sL --proto-redir =http,https --max-time 300 -o "$tmp/$n.mp4" -w '%{http_code}' "$u")"; got=$?
  if [ "$code" = 000 ]; then
    echo "Could not reach Instagram: check the internet connection and try again"
    exit 3
  fi
  if [ "$code" != 200 ]; then
    echo "Address $n was refused ($code): open the reel again and run video-list.js again"
    exit 3
  fi
  if [ "$got" != 0 ]; then
    echo "Address $n stopped before the whole file came: try again"
    exit 3
  fi
done < <(sed 's/\\u0026/\&/g' "$list" | grep -oE 'https?://[A-Za-z0-9._~:/?&=%+-]+' |
  grep -E '\.mp4\?' | sed -E 's/&bytestart=[0-9]+&byteend=[0-9]+//')
[ "$n" -gt 0 ] || { echo "No video addresses in $list"; exit 2; }
has_sound() { [ -n "$(ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 "$1")" ]; }
pic=""; most=0; size=""
for i in $(seq 1 "$n"); do
  wh="$(ffprobe -v error -select_streams V:0 -show_entries stream=width,height -of csv=p=0:s=x "$tmp/$i.mp4")"
  [ -n "$wh" ] || continue
  px=$(( ${wh%x*} * ${wh#*x} ))
  if [ "$px" -gt "$most" ]; then pic="$tmp/$i.mp4"; most="$px"; size="$wh"; fi
done
[ -n "$pic" ] || { echo "None of the addresses held a picture"; exit 3; }
snd=""
if has_sound "$pic"; then snd="$pic"
else
  for i in $(seq 1 "$n"); do
    if has_sound "$tmp/$i.mp4"; then snd="$tmp/$i.mp4"; break; fi
  done
fi
# Join in the temporary folder first, so a stopped save never leaves a
# broken file where a saved reel belongs.
if [ -n "$snd" ] && [ "$snd" != "$pic" ]; then
  ffmpeg -v error -y -i "$pic" -i "$snd" -map 0:V:0 -map 1:a:0 -c copy "$tmp/joined.mp4"
else
  ffmpeg -v error -y -i "$pic" -map 0:V:0 -map '0:a:0?' -c copy "$tmp/joined.mp4"
fi && mkdir -p "$(dirname "$out")" && mv -f "$tmp/joined.mp4" "$out" ||
  { echo "Could not save $out"; exit 3; }
echo "saved $out ($size, $([ -n "$snd" ] && echo with || echo no) sound)"
