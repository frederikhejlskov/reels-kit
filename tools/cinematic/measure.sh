#!/usr/bin/env bash
# measure.sh <video> <out folder> [start seconds] [length seconds]: length,
# shot pace, framing and frames of one video, or of one part of a long one,
# for reference reels and raw clips. Never changes the video. Times it
# writes are seconds in the whole video. A file named "done" in the out
# folder means the measure finished.
set -uo pipefail
in="${1:-}"; out="${2:-}"; from="${3:-0}"; part="${4:-}"
if [ ! -f "$in" ] || [ -z "$out" ]; then
  echo "Give a video file and a folder: measure.sh <video> <out folder>"; exit 1
fi
case "$from$part" in *[!0-9.]*) echo "Start and length are seconds, for example 30 or 12.5"; exit 1 ;; esac
mkdir -p "$out/shots" 2>/dev/null || { echo "Cannot write to $out"; exit 1; }
rm -f "$out/done" "$out"/shots/*.jpg
cut=(-ss "$from"); [ -n "$part" ] && cut+=(-t "$part")
v() { ffprobe -v error -select_streams V:0 -show_entries "$1" \
  -of default=nw=1:nk=1 "$in" 2>/dev/null | head -1; }
len="$(ffprobe -v error -show_entries format=duration \
  -of default=nw=1:nk=1 "$in" 2>/dev/null)"
w="$(v stream=width)"; h="$(v stream=height)"
[ -n "$len" ] || { echo "ffmpeg could not read $in"; exit 1; }
if [ -z "$w" ] || ! awk -v l="$len" 'BEGIN { exit !(l + 0 >= 0.2) }'; then
  echo "Not a video: $in"; exit 1
fi
fps="$(v stream=avg_frame_rate | awk -F/ '{ printf "%.0f", ($2 > 0 ? $1 / $2 : $1) }')"
trc="$(v stream=color_transfer)"
rot="$(v stream_side_data=rotation)"
case "$rot" in 90|-90|270|-270) t="$w"; w="$h"; h="$t" ;; esac
audio=no
[ -n "$(ffprobe -v error -select_streams a -show_entries stream=index \
  -of csv=p=0 "$in" 2>/dev/null)" ] && audio=yes
# A small copy decoded by the Mac's video chip: every step below reads it,
# so a long 4K clip takes seconds, not minutes.
# HDR is converted to standard colour the same way as the colour check in
# "Video tools", so the images show the colour the edit will have.
px="$out/small.mp4"
case "$trc" in
  arib-std-b67|smpte2084)
    case "$rot" in -90|270) turn="transpose=1," ;; 90|-270) turn="transpose=2," ;;
      180|-180) turn="hflip,vflip," ;; *) turn="" ;; esac
    # Coded size before turning, so the output width lands on 480.
    if [ -n "$turn" ] && [ "$turn" != "hflip,vflip," ]; then
      sh_=480; sw_=$(( (480 * $(v stream=width) / $(v stream=height) + 1) / 2 * 2 ))
    else
      sw_=480; sh_=$(( (480 * $(v stream=height) / $(v stream=width) + 1) / 2 * 2 ))
    fi
    ffmpeg-vidstab -nostdin -v error -y -display_rotation 0 -noautorotate \
      -hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld "${cut[@]}" -i "$in" -an \
      -vf "scale_vt=w=$sw_:h=$sh_:color_matrix=bt709:color_primaries=bt709:\
color_transfer=bt709,hwdownload,format=p010le,${turn}format=yuv420p" \
      -c:v h264_videotoolbox -b:v 3M "$px" ;;
  *)
    ffmpeg -nostdin -v error -y -hwaccel videotoolbox "${cut[@]}" -i "$in" -an \
      -vf "scale=480:-2,format=yuv420p" -c:v h264_videotoolbox -b:v 3M "$px" ;;
esac || { echo "Could not read the video in $in"; exit 1; }
# The picture's own length: sound can run longer than the picture.
len="$(ffprobe -v error -show_entries format=duration \
  -of default=nw=1:nk=1 "$px" 2>/dev/null)"
[ -n "$len" ] || { echo "Could not read the video in $in"; exit 1; }
crop="$(ffmpeg -nostdin -v info -i "$px" -an \
  -vf "fps=2,cropdetect=limit=0.1:round=2:reset=1" -f null - 2>&1 |
  grep -o 'crop=[0-9:]*' | sort | uniq -c | sort -rn | awk 'NR==1 {print $2}')"
pw="$(ffprobe -v error -select_streams v:0 -show_entries stream=width \
  -of csv=p=0 "$px")"; ph="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=height -of csv=p=0 "$px")"
cw="$(cut -d= -f2 <<<"$crop" | cut -d: -f1)"; ch="$(cut -d: -f2 <<<"$crop")"
cx="$(cut -d: -f3 <<<"$crop")"; cy="$(cut -d: -f4 <<<"$crop")"
# Bars are the same on both sides; a dark sky on one side is not bars.
bars=no
if [ -n "$cw" ] && [ $((cw * ch * 10)) -lt $((pw * ph * 9)) ]; then
  dx=$((pw - cw - 2 * cx)); dy=$((ph - ch - 2 * cy))
  # and on two sides only: a lit subject in the middle of a dark shot is not bars.
  [ "${dx#-}" -le $((pw / 50 + 2)) ] && [ "${dy#-}" -le $((ph / 50 + 2)) ] &&
    { [ "$cx" -le $((pw / 50 + 2)) ] || [ "$cy" -le $((ph / 50 + 2)) ]; } && bars=yes
fi
scenedetect -q -i "$px" -m 0.2s -o "$out" detect-adaptive list-scenes -f shots.csv \
  >/dev/null 2>&1 || { echo "Shot detection failed on $in"; exit 1; }
# Start and end seconds of every shot; the whole video when no cut was found.
awk -F, 'NR==2 { for (i = 1; i <= NF; i++) { if ($i == "Start Time (seconds)") s = i
  if ($i == "End Time (seconds)") e = i } } NR > 2 && s && e { print $s, $e }' \
  "$out/shots.csv" > "$out/shots.txt"
[ -s "$out/shots.txt" ] || echo "0 $len" > "$out/shots.txt"
# Frame times inside the small copy; index.txt adds the part's start back.
n="$(wc -l < "$out/shots.txt" | tr -d ' ')"
lens="$(awk '{ printf "%.2f\n", $2 - $1 }' "$out/shots.txt" | sort -n)"
mid="$(awk '{ a[NR] = $1 } END { printf "%.1f", (NR % 2 ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2) }' <<<"$lens")"
lo="$(head -1 <<<"$lens" | awk '{ printf "%.1f", $1 }')"
hi="$(tail -1 <<<"$lens" | awk '{ printf "%.1f", $1 }')"
{
  printf 'length %.1f s\n' "$len"
  [ "$from" != 0 ] || [ -n "$part" ] && printf 'part from %s s of the video\n' "$from"
  echo "size ${w}x${h}"
  echo "frame rate $fps"
  [ "$fps" -ge 50 ] && echo "slow motion ready"
  case "$trc" in arib-std-b67|smpte2084) echo "hdr yes" ;; *) echo "hdr no" ;; esac
  echo "rotation ${rot:-none}"
  if [ "$bars" = yes ]; then
    echo "picture $((cw * w / pw))x$((ch * h / ph)) inside the frame (black bars)"
  else
    echo "picture fills the frame"
  fi
  echo "audio $audio"
  echo "shots $n"
  echo "shot length typical $mid s, shortest $lo s, longest $hi s"
} > "$out/measure.txt"
ffmpeg -nostdin -v error -y -i "$px" \
  -vf "fps=12/$len,scale=180:-2,tile=6x2" -frames:v 1 "$out/sheet.jpg" ||
  { echo "Could not make the frame sheet for $in"; exit 1; }
# Pieces to look at: each shot, with takes over 4 s split into pieces of
# 3 s or less, so a long take shows every moment. shots/index.txt maps each
# image to its shot and times.
awk '{ d = $2 - $1; k = (d > 4 ? int((d + 2.999) / 3) : 1)
  for (j = 0; j < k; j++) printf "%d %.3f %.3f\n", NR, $1 + d * j / k, $1 + d * (j + 1) / k }' \
  "$out/shots.txt" > "$out/pieces.txt"
: > "$out/shots/index.txt"
i=0
while read -r shot s e && [ "$i" -lt 120 ]; do
  i=$((i + 1)); img="$(printf %03d "$i").jpg"
  # Never past the last frame: a very short last shot still gets an image.
  read -r t1 t2 t3 <<<"$(awk -v s="$s" -v e="$e" -v l="$len" -v f="$fps" \
    'BEGIN { d = (e - s) / 10; m = l - 2 / (f > 0 ? f : 30); if (m < 0) m = 0
      a = s + d; b = (s + e) / 2; c = e - d; if (a > m) a = m; if (b > m) b = m; if (c > m) c = m
      printf "%.3f %.3f %.3f", a, b, c }')"
  ffmpeg -nostdin -v error -y -ss "$t1" -i "$px" -ss "$t2" -i "$px" -ss "$t3" -i "$px" \
    -filter_complex "[0:v]scale=320:-2[a];[1:v]scale=320:-2[b];[2:v]scale=320:-2[c];[a][b][c]hstack=3" \
    -frames:v 1 "$out/shots/$img" ||
    { echo "Could not make the frames for shot $shot of $in"; exit 1; }
  awk -v i="$img" -v n="$shot" -v s="$s" -v e="$e" -v f="$from" \
    'BEGIN { printf "%s shot %s, %.1f to %.1f s\n", i, n, s + f, e + f }' >> "$out/shots/index.txt"
done < "$out/pieces.txt"
p="$(wc -l < "$out/pieces.txt" | tr -d ' ')"
[ "$p" -gt 120 ] && echo "images for the first 120 of $p pieces only" >> "$out/measure.txt"
touch "$out/done"
cat "$out/measure.txt"
