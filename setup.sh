#!/usr/bin/env bash
# Sets up the Reels kit on this Mac. Safe to run more than once.
#   bash setup.sh          install what is missing, then check
#   bash setup.sh --check  only report what is missing (exit 1 if anything is)
#   bash setup.sh --update take a newer version of the kit's own files, if any
# Run it from the Reels folder it came in; that folder is where the reels are made.
# REELS_DIR overrides the folder; used for testing.
# Lines starting "ACTION:" are steps only the person at the Mac can do. Exit 3
# means one is waiting: do it, then run setup.sh again. Exit 4: setup is
# already running. Exit 5: the kit needs an update. Exit 6: this Mac is not
# ready; the numbered list says what to fix first.
# Installs only what is missing: never replaces a Node, Python or any
# Homebrew package the Mac already has.
# Video tools live in .tools/ inside the Reels folder.
# Palmier Pro, the editor, goes in Applications (macOS 26 or newer only).
# PALMIER_APPS_DIR overrides that folder; used for testing.
set -uo pipefail
unset BREW_DRY # only the check before installing sets it, for one call at a time
if [ "$#" -gt 1 ]; then echo "Use --check, --update or no arguments"; exit 2; fi
case "${1:-}" in ""|--check|--update) ;; *) echo "Unknown option: $1 (use --check, --update or nothing)"; exit 2;; esac
KIT="$(cd "$(dirname "$0")" && pwd)"
REELS="${REELS_DIR:-$KIT}"
MARKER='<!-- reels-kit instructions v24 -->'
# Where newer versions of the kit come from, and the key their file list
# must be signed with. A version is taken only when that signature is good,
# every file matches the list, and it is newer than the one in this folder.
UPDATE_SOURCE='https://raw.githubusercontent.com/frederikhejlskov/reels-kit'
UPDATE_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFaLTMlnOSEGPtIk0bQYk7OUxcsAqZjbl9i0RnhEVW7S'
export HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
export HYPERFRAMES_NO_TELEMETRY=1

fresh() {
  local -a clean_env=("HOME=$HOME" "USER=${USER:-$(id -un)}" "LOGNAME=${LOGNAME:-${USER:-$(id -un)}}" "TERM=xterm-256color")
  if [ "${CLAUDE_CONFIG_DIR+x}" ]; then clean_env+=("CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"); fi
  env -i "${clean_env[@]}" /bin/zsh -ilc "$@"
}

missing=0
# Every check runs in a fresh login shell: it proves a new Terminal window works.
line() { # line "<name>" "<zsh test>"
  if fresh "$2" "${@:3}" >/dev/null 2>&1; then echo "OK    $1"; else echo "MISS  $1: install or fix $1, then rerun setup.sh --check"; missing=1; fi
}
# The same tests are used during setup and in a new login shell.
INSTAGRAM_MARKETPLACE='Jakeschincariol/instagram-agent-skill#d03c56bb598be770c60b201f94237e5d1a4268a6'
HYPERFRAMES_MARKETPLACE='heygen-com/hyperframes#58ef24c6d88634ff42f60b0435f3685ccfa2d459'
# Palmier Pro is downloaded from Palmier's own release page, never copied
# from this kit, and must be signed by Palmier, Inc. and notarized by Apple.
PALMIER_URL=https://github.com/palmier-io/palmier-pro/releases/download/v0.12.1/PalmierPro.dmg
PALMIER_SHA=05d96a0130a5da21ee40fbc0591f3a7eb1746c841fde32769948c0d839e40789
PALMIER_TEAM=MMFLRC7562
PALMIER_SKILLS=040e82ffab6f616aec5d1ed4541a1d0260a95613
macos_major() { local v; v="$(sw_vers -productVersion 2>/dev/null)"; echo "${v%%.*}"; }
palmier_fits() { [ "$(macos_major)" -ge 26 ] 2>/dev/null && [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; }
palmier_app() { # prints the installed app's path
  local a
  for a in "${PALMIER_APPS_DIR:-/Applications}/PalmierPro.app" "$HOME/Applications/PalmierPro.app"; do
    [ -d "$a" ] && { echo "$a"; return 0; }
  done
  return 1
}
palmier_signed() { # palmier_signed <app>: Palmier's own app, unchanged, notarized
  codesign --verify --deep --strict "$1" 2>/dev/null || return 1
  [ "$(codesign -dv "$1" 2>&1 | sed -n 's/^TeamIdentifier=//p')" = "$PALMIER_TEAM" ] || return 1
  spctl -a -t exec "$1" 2>/dev/null
}
palmier_drop() { # palmier_drop <work>: unmount, then remove the folder only once nothing is mounted in it
  hdiutil detach -quiet "$1/mnt" 2>/dev/null || hdiutil detach -force -quiet "$1/mnt" 2>/dev/null
  [ -d "$1/mnt/PalmierPro.app" ] || rm -rf "$1"
}
palmier_skills_ok() { [ "$(cat "$REELS/.tools/palmier-skills/.commit" 2>/dev/null)" = "$PALMIER_SKILLS" ] && [ -f "$REELS/.tools/palmier-skills/skills/color-grading/SKILL.md" ]; }
AUTO_SHA=50e7a86f7566389313a07f991dcb7a8c4d1a4dbae7d37bc00f17f59d969877d1
DEMUCS_SHA=d9fa14133cfcc034a6758923bb3a8ca9f8dfd0b582134643bbf83f72c17576dd
DEMUCS_YAML_SHA=239c445d0b14454d541ad8bd9bb271c9e536d267e8a4625208744cbb2e7bb66c
DEMUCS_REV=cbc8a9b1a87023b7fd74e7b3412e6321c0eab003
REMBG_SHA=60920e99c45464f2ba57bee2ad08c919a52bbf852739e96947fbb4358c0d964a
scene_test='test -x "$1/.tools/venv/bin/scenedetect" && "$2" scenedetect version'
auto_test='test -x "$1/.tools/venv/bin/auto-editor" && test -x "$1/.tools/venv/bin/python" && p="$("$1/.tools/venv/bin/python" -c "import auto_editor,os;print(os.path.dirname(auto_editor.__file__))")/bin/auto-editor" && test -x "$p" && test "$(shasum -a 256 "$p" | cut -d " " -f 1)" = "$4" && "$2" auto-editor --version'
# FFmpeg 8.1.1, which older kits built, garbles steadied clips when it runs
# on several cores: a kit with any other version than this one rebuilds.
# vidstab_test says vid.stab works (the check and the final check use it);
# vidstab_current also needs this version, and only decides on a rebuild.
FFMPEG_VERSION=9.1
FFMPEG_SHA=1a4d394ae63d190a526cd052eb4415c156b5c5e2df37efab41a7de0b8fde2433
vidstab_test='test -x "$1/.tools/ffmpeg-vidstab/bin/ffmpeg-vidstab" && { out="$("$2" "$1/.tools/ffmpeg-vidstab/bin/ffmpeg-vidstab" -hide_banner -filters 2>&1)" && printf "%s\n" "$out" | grep vidstabtransform >/dev/null || { printf "%s\n" "$out"; false; }; }'
vidstab_current="$vidstab_test"' && "$2" "$1/.tools/ffmpeg-vidstab/bin/ffmpeg-vidstab" -version | head -n 1 | grep -q "^ffmpeg version '"$FFMPEG_VERSION"' "'
color_test='test -x "$1/.tools/venv/bin/color-matcher" && "$2" color-matcher -h'
rembg_test='test -x "$1/.tools/venv/bin/rembg" && "$2" rembg --help && { test "$3" = packages || { p="$1/.tools/models/models/isnet-general-use/isnet-general-use.onnx" && test -f "$p" && test "$(shasum -a 256 "$p" | cut -d " " -f 1)" = "$5"; }; }'
rife_test='test -x "$1/.tools/rife/rife-ncnn-vulkan" && test -f "$1/.tools/rife/rife-v4.6/flownet.bin" && test -f "$1/.tools/rife/rife-v4.6/flownet.param" && { out="$("$2" rife-ncnn-vulkan -h 2>&1)"; printf "%s\n" "$out" | grep -qi usage || { printf "%s\n" "$out"; false; }; }'
esrgan_test='test -x "$1/.tools/realesrgan/realesrgan-ncnn-vulkan" && test -f "$1/.tools/realesrgan/models/realesrgan-x4plus.bin" && test -f "$1/.tools/realesrgan/models/realesrgan-x4plus.param" && { out="$("$2" realesrgan-ncnn-vulkan -h 2>&1)"; printf "%s\n" "$out" | grep -qi usage || { printf "%s\n" "$out"; false; }; }'
demucs_test='test -x "$1/.tools/venv/bin/demucs" && "$2" demucs --help && { test "$3" = packages || { p="$1/.tools/models/hub/models--adefossez--HTDemucs/blobs/$6" && y="$1/.tools/models/hub/models--adefossez--HTDemucs/snapshots/$8/htdemucs.yaml" && test -f "$p" && test "$(shasum -a 256 "$p" | cut -d " " -f 1)" = "$6" && test -f "$y" && test "$(shasum -a 256 "$y" | cut -d " " -f 1)" = "$7" && "$2" env HF_HUB_OFFLINE=1 python -c "from huggingface_hub import hf_hub_download as d; [d(\"adefossez/HTDemucs\", f) for f in (\"htdemucs.yaml\",\"955717e8.safetensors\")]"; }; }'
librosa_test='test -x "$1/.tools/venv/bin/python" && "$2" python -c "import librosa"'
video_ok() {
  local output
  if output="$(fresh "$1" _ "$REELS" "$2" "${3:-full}" "$AUTO_SHA" "$REMBG_SHA" "$DEMUCS_SHA" "$DEMUCS_YAML_SHA" "$DEMUCS_REV" 2>&1)"; then return 0; fi
  [ -z "$output" ] || printf '%s\n' "$output" | tail -n 15
  return 1
}
video_line() {
  if video_ok "$2" "$REELS/.tools/run"; then echo "OK    $1"; else echo "MISS  $1: install or fix $1, then rerun setup.sh --check"; missing=1; return 1; fi
}

# plugin_field <id> <field>: prints the field of the plugin enabled for this
# exact folder at project scope; exits 1 if there is no such install.
resolve_claude() {
  # Anthropic's own copy first: it is the one setup installs and keeps
  # current, also when another copy (Homebrew, npm) comes first on the PATH.
  if [ -x "$HOME/.local/bin/claude" ]; then claude_bin="$HOME/.local/bin/claude"; return 0; fi
  # Startup files may print to stdout, so the command's path is the last line.
  claude_bin="$(fresh 'printf "\n"; whence -p claude' | tail -n 1)" || return 1
  [ -n "$claude_bin" ] && [ -x "$claude_bin" ]
}
plugin_field() {
  local json
  [ -n "${claude_bin:-}" ] || return 1
  if [ "${1:-}" = "--quiet-errors" ]; then
    shift
    json="$(cd "$REELS" && "$claude_bin" plugin list --json 2>/dev/null)" || return 1
  else
    json="$(cd "$REELS" && "$claude_bin" plugin list --json)" || return 1
  fi
  printf '%s' "$json" | node -e '
    const [id, dir, field] = process.argv.slice(1); let s = "";
    process.stdin.on("data", d => s += d).on("end", () => {
      let list = []; try { list = JSON.parse(s); } catch { process.exit(1); }
      if (!Array.isArray(list)) process.exit(1);
      const p = list.find(p => p.id === id && p.scope === "project" && p.projectPath === dir && p.enabled === true);
      if (!p) process.exit(1);
      console.log(p[field]); process.exit(0);
    });' "$1" "$REELS" "$2" 2>/dev/null
}

# A folder the creator moves into this one may carry its own CLAUDE.md,
# AGENTS.md or rules, which Claude would load as instructions next to the
# kit's. This setting keeps them out, so they stay notes. It also keeps out
# the CLAUDE.md and AGENTS.md that HyperFrames copies into each project,
# which the kit's own rules replace. fence check|write
# ponytail: the folder path is used as a glob as it is; a path with * ? [ {
# in it would need escaping.
fence() {
  /usr/bin/python3 - "$REELS" "$1" <<'PY'
import json, os, sys
reels, mode = sys.argv[1], sys.argv[2]
want = [os.path.join(reels, "*", "**", name) for name in
        ("CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", ".claude/rules/**")]
path = os.path.join(reels, ".claude", "settings.json")
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
have = data.get("claudeMdExcludes") or []
if mode == "check":
    sys.exit(0 if all(w in have for w in want) else 1)
data["claudeMdExcludes"] = have + [w for w in want if w not in have]
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path + ".partial", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(path + ".partial", path)
PY
}

check() {
  missing=0
  [ -d "$REELS" ] && REELS="$(cd "$REELS" && pwd -P)"
  # The plugin lines below run node from this PATH: use a new Terminal's, so
  # a session started without it does not report tools missing that are there.
  local login; login="$(fresh 'printf "\n%s" "$PATH"' 2>/dev/null | tail -n 1)" && [ -n "$login" ] && PATH="$login:$PATH"
  line "Homebrew" "command -v brew"
  line "Node 22+" "node -e 'process.exit(+process.versions.node.split(\".\")[0] < 22 ? 1 : 0)'"
  line "FFmpeg" "command -v ffmpeg"
  line "FFprobe" "command -v ffprobe"
  line "Python 3" "python3 -c 1"
  line "whisper.cpp" "command -v whisper-cli"
  line "Google Chrome" "test -d '/Applications/Google Chrome.app' || test -d \"\$HOME/Applications/Google Chrome.app\""
  line "Claude Code" "command -v claude"
  if fresh 'head -1 "$1" | grep -qF "$2"' _ "$REELS/CLAUDE.md" "$MARKER" >/dev/null 2>&1; then
    echo "OK    Reels instruction file"; else echo "MISS  Reels instruction file: put the kit's CLAUDE.md in this folder"; missing=1; fi
  if [ -s "$REELS/tools/script/script.md" ]; then echo "OK    Script method"; else echo "MISS  Script method: copy the kit's tools folder into this folder"; missing=1; fi
  if [ -e "$REELS/.kit-update-pending" ]; then echo "MISS  Kit update: run setup.sh to finish it"; missing=1; fi
  resolve_claude >/dev/null 2>&1 || claude_bin=''
  if plugin_field --quiet-errors instagram-agent@instagram-agent-skill id >/dev/null; then echo "OK    Instagram skills"; else echo "MISS  Instagram skills"; missing=1; fi
  local hf; hf="$(plugin_field --quiet-errors hyperframes@hyperframes installPath)"
  if [ -n "$hf" ] && (cd "$REELS" && node "$hf/skills/hyperframes/scripts/plugin-cli.mjs" --version) >/dev/null 2>&1; then
    echo "OK    HyperFrames"; else echo "MISS  HyperFrames"; missing=1; fi
  if fence check 2>/dev/null; then echo "OK    Other folders' instructions kept out"
  else echo "MISS  Other folders' instructions kept out: run setup.sh"; missing=1; fi
  if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != 1 ]; then
    echo "MISS  Video tools: The video tools need a Mac with Apple silicon (M1 or newer)."
    missing=1
  else
    video_line "PySceneDetect" "$scene_test"
    video_line "Auto-Editor" "$auto_test"
    # A kit that kept its old build after a failed rebuild steadies badly:
    # LATER makes the session run setup again before it steadies a clip.
    if video_ok "$vidstab_test" "$REELS/.tools/run" && ! video_ok "$vidstab_current" "$REELS/.tools/run"; then
      echo "LATER vid.stab: its update is not finished; run setup.sh to try again"
    else video_line "vid.stab" "$vidstab_test"; fi
    video_line "color-matcher" "$color_test"
    video_line "rembg" "$rembg_test"
    video_line "RIFE" "$rife_test"
    video_line "Real-ESRGAN" "$esrgan_test"
    video_line "Demucs" "$demucs_test"
    video_line "librosa" "$librosa_test"
  fi
  if palmier_fits; then
    local app; app="$(palmier_app)"
    if [ -z "$app" ]; then echo "LATER Palmier Pro: not installed yet, so reels are edited with HyperFrames; run setup.sh to try again"
    elif palmier_signed "$app"; then echo "OK    Palmier Pro"
    else echo "SKIP  Palmier Pro: the copy in $(dirname "$app") could not be verified as Palmier's own app, so reels are edited with HyperFrames"; fi
    if palmier_skills_ok; then echo "OK    Palmier editing guides"; else echo "LATER Palmier editing guides: not installed yet; run setup.sh to try again"; fi
  else
    echo "SKIP  Palmier Pro: it needs macOS 26 or newer on Apple silicon, so reels are edited with HyperFrames on this Mac"
  fi
  return $missing
}

if [ "${1:-}" = "--check" ]; then check; exit $?; fi

# One setup at a time: a second copy would download and install twice.
# The lock is a link whose target is the running setup's process ID, made in one step.
lock="$REELS/.setup.lock"
mkdir -p "$REELS" || exit 1
setup_running() { # setup_running <pid>: that process exists and is a setup.sh
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null && ps -p "$1" -o command= 2>/dev/null | grep -qF setup.sh
}

# Run from the home folder itself (or Downloads, Desktop, Documents), setup
# would treat that whole folder as the Reels folder and write its settings
# and tools there. Refused before anything is written, also for --update.
own_folder() {
  local f h d
  f="$(cd "$REELS" 2>/dev/null && pwd -P)" || return 0
  for d in "$HOME" "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents"; do
    h="$(cd "$d" 2>/dev/null && pwd -P)" && [ "$f" = "$h" ] && return 1
  done
  return 0
}
own_folder || {
  echo "This Mac is not ready for the kit yet. Nothing was installed. Fix these, then run setup again:"
  echo "1. setup.sh is not in a folder of its own. Make a new folder called Reels in your home folder, move setup.sh into it, open that folder in Claude and paste the install message again."
  exit 6
}

# --update: replace the kit's own files (CLAUDE.md, README.md, setup.sh and
# tools/) with a newer signed version. Never touches anything else in the
# folder. Prints a line starting UPDATED or UPDATE; a full setup run then
# finishes the update (the check reports it until that run ends).
kit_version() { sed -n '1s/.*reels-kit instructions v\([0-9][0-9]*\).*/\1/p' "$1" 2>/dev/null; }
kit_path_ok() { # only the kit's own files, never a path that leaves them
  case "$1" in
    CLAUDE.md|README.md|setup.sh) return 0 ;;
    *..*|*//*|*[!A-Za-z0-9._/-]*|*/) return 1 ;;
    tools/?*) return 0 ;;
  esac
  return 1
}
kit_place_ok() { # kit_place_ok <path>: no link on the way, and the place itself is a plain file or free
  local p="$REELS" rest="$1"
  while [ -n "$rest" ]; do
    p="$p/${rest%%/*}"
    [ ! -L "$p" ] || return 1
    case "$rest" in
      */*) rest="${rest#*/}"; [ ! -e "$p" ] || [ -d "$p" ] || return 1 ;;
      *) rest=''; [ ! -e "$p" ] || [ -f "$p" ] || return 1 ;;
    esac
  done
}
upd_get() { curl -fsSL --proto-redir =https --connect-timeout 5 --max-time 60 --max-filesize 5000000 "$1" -o "$2" 2>/dev/null; }
update() {
  local have want work notes sum path line
  local refused="UPDATE refused: the newer version could not be checked as the kit's own, so nothing changed."
  local nowrite="UPDATE skipped: could not write in this folder. Nothing changed."
  local nonet="UPDATE skipped: the update address could not be reached. Nothing changed."
  REELS="$(cd "$REELS" && pwd -P)" || { echo "$nowrite"; return 0; }
  rm -rf "$REELS"/.kit-update.??????
  have="$(kit_version "$REELS/CLAUDE.md")"; have="${have:-0}"
  work="$(mktemp -d "$REELS/.kit-update.XXXXXX")" || { echo "$nowrite"; return 0; }
  # main only says which version is the newest. The file list and its
  # signature come from that version's own tag, which never changes, so the
  # two always belong together.
  upd_get "$UPDATE_SOURCE/main/kit.manifest" "$work/hint" || { echo "$nonet"; return 0; }
  want="$(sed -n '1s/^reels-kit \([0-9][0-9]*\)$/\1/p' "$work/hint")"
  [ -n "$want" ] || { echo "$refused"; return 0; }
  [ "$want" -gt "$have" ] || { echo "UPDATE none: this is the newest version."; return 0; }
  upd_get "$UPDATE_SOURCE/v$want/kit.manifest" "$work/manifest" && upd_get "$UPDATE_SOURCE/v$want/kit.manifest.sig" "$work/manifest.sig" || { echo "$nonet"; return 0; }
  echo "reels-kit $UPDATE_KEY" > "$work/allowed"
  /usr/bin/ssh-keygen -Y verify -f "$work/allowed" -I reels-kit -n reels-kit-update -s "$work/manifest.sig" < "$work/manifest" >/dev/null 2>&1 || { echo "$refused"; return 0; }
  [ "$(sed -n '1s/^reels-kit \([0-9][0-9]*\)$/\1/p' "$work/manifest")" = "$want" ] || { echo "$refused"; return 0; }
  notes="$(sed -n '2s/^notes //p' "$work/manifest")"
  tail -n +3 "$work/manifest" > "$work/list" && cut -c67- "$work/list" > "$work/paths" || { echo "$nowrite"; return 0; }
  grep -qxF CLAUDE.md "$work/paths" && grep -qxF setup.sh "$work/paths" && [ -z "$(LC_ALL=C sort "$work/paths" | uniq -d)" ] || { echo "$refused"; return 0; }
  mkdir "$work/new" || { echo "$nowrite"; return 0; }
  while IFS= read -r line; do
    sum="${line%%  *}"; path="${line#*  }"
    [ "${#sum}" -eq 64 ] && kit_path_ok "$path" || { echo "$refused"; return 0; }
    kit_place_ok "$path" || { echo "UPDATE stopped: $path in this folder is a link or a folder, so the kit left everything as it was."; return 0; }
    mkdir -p "$work/new/$(dirname "$path")" || { echo "$nowrite"; return 0; }
    upd_get "$UPDATE_SOURCE/v$want/$path" "$work/new/$path" || { echo "$nonet"; return 0; }
    [ "$(shasum -a 256 "$work/new/$path" | cut -d' ' -f1)" = "$sum" ] || { echo "$refused"; return 0; }
  done < "$work/list"
  [ "$(kit_version "$work/new/CLAUDE.md")" = "$want" ] && grep -q "^MARKER='<!-- reels-kit instructions v$want -->'$" "$work/new/setup.sh" &&
    /bin/bash -n "$work/new/setup.sh" 2>/dev/null || { echo "$refused"; return 0; }
  # Kit files the newer version no longer has: only ones an earlier update
  # put here, and only while they are still exactly that file.
  : > "$work/old"; [ ! -f "$REELS/.kit.manifest" ] || tail -n +3 "$REELS/.kit.manifest" > "$work/old"
  cp "$work/manifest" "$REELS/.kit.manifest" && : > "$REELS/.kit-update-pending" || { echo "$nowrite"; return 0; }
  while IFS= read -r line; do
    sum="${line%%  *}"; path="${line#*  }"
    kit_path_ok "$path" && kit_place_ok "$path" && [ -f "$REELS/$path" ] && ! grep -qxF "$path" "$work/paths" &&
      [ "$(shasum -a 256 "$REELS/$path" | cut -d' ' -f1)" = "$sum" ] && rm -f "$REELS/$path"
  done < "$work/old"
  # CLAUDE.md carries the version, so it goes last: a stopped update runs again.
  { grep -vxF CLAUDE.md "$work/paths"; echo CLAUDE.md; } > "$work/order"
  while IFS= read -r path; do
    mkdir -p "$REELS/$(dirname "$path")" && mv -f "$work/new/$path" "$REELS/$path" || {
      echo "UPDATE stopped: could not replace $path. Run the update again."; return 0; }
  done < "$work/order"
  echo "UPDATED version $have to $want: $notes"
  echo "Next: run bash setup.sh, then read CLAUDE.md again. It changed."
}
# A full setup run finishes an update. The mark stays while setup.sh and
# CLAUDE.md are not the same version: the next --update repairs that.
update_done() { [ "$(head -1 "$REELS/CLAUDE.md" 2>/dev/null)" != "$MARKER" ] || rm -f "$REELS/.kit-update-pending"; }
if [ "${1:-}" = "--update" ]; then
  # One at a time, and never beside a running setup: the same lock.
  if ! ln -s "$$" "$lock" 2>/dev/null; then
    setup_running "$(readlink "$lock" 2>/dev/null)" && { echo "UPDATE skipped: setup or another update is running."; exit 0; }
    rm -f "$lock"
    ln -s "$$" "$lock" 2>/dev/null || { echo "UPDATE skipped: setup or another update is running."; exit 0; }
  fi
  trap 'rm -rf "$REELS"/.kit-update.??????; rm -f "$lock"' EXIT
  update; exit 0
fi

NOWRITE="Setup cannot create files in this folder ($REELS). Claude may not be allowed to change it, or it is on a disk the tools cannot use (a camera card or an external disk for Windows). Nothing was installed. Move the Reels folder to your home folder, open it there in Claude and say install."
if ! ln -s "$$" "$lock" 2>/dev/null; then
  [ -L "$lock" ] || { echo "$NOWRITE"; exit 1; }
  setup_running "$(readlink "$lock" 2>/dev/null)" && { echo "Setup is already running. Wait for it to finish."; exit 4; }
  rm -f "$lock"
  ln -s "$$" "$lock" 2>/dev/null || { echo "Setup is already running. Wait for it to finish."; exit 4; }
fi
pkg_dir=''
clean_palmier_temp() { # unmount a half-finished Palmier install before removing its folder
  local d
  for d in "$REELS/.tools"/palmier.??????; do
    [ -d "$d" ] && palmier_drop "$d"
  done
  rm -rf "$REELS/.tools"/palmier-skills.?????? "${PALMIER_APPS_DIR:-/Applications}/.PalmierPro.app.partial" "$HOME/Applications/.PalmierPro.app.partial"
}
clean_video_temp() {
  local dir
  [ -n "${TOOLS:-}" ] || return 0
  for dir in "$TOOLS"/*-build.* "$TOOLS"/demucs.*; do
    [ ! -d "$dir" ] || rm -rf "$dir"
  done
  rm -f "$TOOLS/.run.partial" "$TOOLS/ffmpeg-build.log"
}
cleanup() { clean_video_temp; clean_palmier_temp; rm -f "$lock"; [ -z "$pkg_dir" ] || rm -rf "$pkg_dir"; [ -z "${pre_dir:-}" ] || rm -rf "$pre_dir"; }
trap cleanup EXIT

download() { curl -fsSL --retry 3 --connect-timeout 30 --speed-limit 1024 --speed-time 60 "$@"; }
sha_ok() {
  local actual
  actual="$(shasum -a 256 "$1" 2>/dev/null)" || { rm -f "$1"; return 1; }
  if [ "${actual%% *}" = "$2" ]; then return 0; fi
  rm -f "$1"
  return 1
}
fetch_pinned() {
  local url="$1" hash="$2" dest="$3" tool="$4"
  download "$url" -o "$dest" || { rm -f "$dest"; echo "$tool download failed. Check the internet connection, then run setup again."; return 1; }
  sha_ok "$dest" "$hash" || { echo "$tool: The download did not match the expected file. Nothing was installed. Run setup again later."; return 1; }
}
fetch_run() { # fetch_run <url>: download to a file first so a failed download stops here
  local f; f="$(mktemp)" || return 1
  download "$1" -o "$f" || { rm -f "$f"; return 1; }
  /bin/bash "$f"; local c=$?; rm -f "$f"; return $c
}
profile_add() { # profile_add <command> <line>: only when a fresh login shell can't find <command>
  fresh 'whence -p "$1"' _ "$1" >/dev/null 2>&1 || grep -qsF "$2" "$HOME/.zprofile" || echo "$2" >> "$HOME/.zprofile"
}
has() { fresh 'command -v "$1"' _ "$1" >/dev/null 2>&1; } # same test as the check

# Homebrew ships ready-made packages only for recent macOS versions. On an
# older macOS it builds each one from source: hours at full load, and more
# memory than a small Mac has. brew_ready is true when every name given has
# a ready-made package for this Mac, or when that cannot be told.
brew_ready() {
  local json
  json="$(brew info --json=v2 --formula "$@" 2>/dev/null)" || return 0
  printf '%s' "$json" | /usr/bin/python3 -c 'import json, sys
try:
    formulae = json.load(sys.stdin)["formulae"]
    missing = any(not ((f.get("bottle") or {}).get("stable") or {}).get("files") for f in formulae)
except Exception:
    sys.exit(0)
sys.exit(1 if missing else 0)' 2>/dev/null
  [ $? -ne 1 ]   # only a clear "no ready-made package" blocks; a failed check does not
}
brew_install() { # Refuse installs that would change an installed package or build from source.
  local formula kind deps outdated installed dep item blocked=""
  formula="${@: -1}"
  kind=--formula
  [ "${1:-}" = --cask ] && kind=--cask
  installed="$(brew list "$kind" --versions)" || {
    echo "Could not check installed packages. Check Homebrew, then rerun setup.sh."
    return 1
  }
  while IFS= read -r item; do
    item="${item%% *}"
    if [ "$item" = "$formula" ] || [ "${item##*/}" = "${formula##*/}" ]; then
      # Installed but its command is missing: an interrupted install left it
      # unlinked. Linking changes no version.
      if [ "$kind" = --formula ]; then [ -n "${BREW_DRY:-}" ] || brew link "$formula"; return; fi
      printf 'Cannot install %s: it is already installed. Reinstall it yourself, then rerun setup.sh.\n' "$formula"
      return 1
    fi
  done <<< "$installed"
  deps="$(brew deps "$kind" "$formula")" || {
    echo "Could not check dependencies for $formula. Check Homebrew, then rerun setup.sh."
    return 1
  }
  outdated="$(brew outdated --formula --quiet)" || {
    echo "Could not check outdated packages. Check Homebrew, then rerun setup.sh."
    return 1
  }
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      if [ "$dep" = "$item" ] || [ "${dep##*/}" = "${item##*/}" ]; then
        blocked="${blocked}${blocked:+, }$dep (outdated dependency)"
        break
      fi
    done <<< "$outdated"
  done <<< "$deps"
  if [ -n "$blocked" ]; then
    printf 'Cannot install %s without changing installed packages: %s. Update or install them yourself, then rerun setup.sh.\n' "$formula" "$blocked"
    return 1
  fi
  if [ "$kind" = --formula ] && ! brew_ready "$formula" $deps; then
    printf 'This version of macOS is too old for the ready-made %s: installing it would mean hours of building on this Mac, so it was not installed. Update macOS (System Settings, General, Software Update), then run setup again.\n' "$formula"
    return 1
  fi
  [ -z "${BREW_DRY:-}" ] || return 0 # the check before installing: only say what would stop it
  brew install "$@"
}

BREW_BIN="${REELS_BREW_BIN:-/opt/homebrew/bin/brew}" # override only for tests
have_clt() { xcode-select -p >/dev/null 2>&1 && [ -x "$(xcode-select -p)/usr/bin/git" ]; }
# A Mac set up from an old Intel Mac brings a Homebrew in /usr/local that
# has no ready-made packages for an Apple chip. While the kit's tools still
# have to be installed, only Homebrew in /opt/homebrew counts there: setup
# adds this Mac's own beside the old one and leaves the old one alone. Once
# the tools are installed, whatever Homebrew is there is left as it is.
have_brew() {
  [ -x "$BREW_BIN" ] && return 0
  command -v brew >/dev/null || return 1
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != 1 ] || [ -x "$REELS/.tools/run" ]
}
wait_for_clt() { # true once installed; false after 8 minutes or once the window is gone
  local start=$SECONDS
  until have_clt; do
    [ $((SECONDS - start)) -ge 480 ] && return 1
    if [ $((SECONDS - start)) -ge 30 ] && ! pgrep -f "Install Command Line Developer Tools" >/dev/null 2>&1; then return 1; fi
    sleep 5
  done
}

# Homebrew signs its Mac installer with a maintainer's Developer ID; this team
# is the one Homebrew's own release build checks for (Homebrew/BrewUI
# build.yml). If Homebrew changes it, setup stops with exit 5 and this kit
# needs the new ID.
HOMEBREW_TEAM=927JGANW46
verify_pkg() { # 0 Homebrew's package, 1 not signed and notarized, 2 another signer
  local sig
  sig="$(pkgutil --check-signature "$1" 2>&1)" || return 1
  grep -qF 'Status: signed by a developer certificate issued by Apple for distribution' <<<"$sig" || return 1
  spctl -a -t install "$1" >/dev/null 2>&1 || return 1
  grep -qE "^ +1\. Developer ID Installer: .*\($HOMEBREW_TEAM\)\$" <<<"$sig" || return 2
}
# Runs as root: copies the package where this user cannot change it, checks it
# again there, then installs that copy.
ROOT_INSTALL='d=$(/usr/bin/mktemp -d /private/var/tmp/reels-brew.XXXXXX) || exit 1
trap "/bin/rm -rf \"$d\"" EXIT
/bin/cp "$1" "$d/h.pkg" || exit 1
s=$(/usr/sbin/pkgutil --check-signature "$d/h.pkg") || exit 1
case "$s" in *"issued by Apple for distribution"*) ;; *) exit 1 ;; esac
printf "%s\n" "$s" | /usr/bin/grep -Eq "^ +1\. Developer ID Installer: .*\($2\)\$" || exit 1
/usr/sbin/spctl -a -t install "$d/h.pkg" || exit 1
/usr/sbin/installer -pkg "$d/h.pkg" -target /'

# Stop before installing anything on a Mac the tools cannot run on. Homebrew
# has ready-made packages only for recent macOS versions; on an older one it
# would build everything from source for hours.
mac_fits() {
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || { echo "The kit needs a Mac with an Apple chip (M1 or newer). Nothing was installed."; return 1; }
  [ "$(macos_major)" -ge 15 ] 2>/dev/null || { echo "This Mac needs macOS 15 or newer. Nothing was installed. Update macOS (System Settings, General, Software Update), then run setup again."; return 1; }
}
# Written before anything can stop setup, so a Mac that setup refuses still
# keeps other folders' instructions out. Needs Apple's python3, which exists
# once the command line tools do.
have_clt && ( REELS="$(cd "$REELS" && pwd -P)" && fence write ) 2>/dev/null
mac_fits >/dev/null 2>&1 || rm -f "$REELS/.kit-update-pending" # nothing to finish on a Mac setup refuses
mac_fits || exit 1

# Check this Mac before installing anything: everything the install relies on
# that setup cannot put right by itself, as one list, so nobody finds out
# twenty minutes in. Installs and changes nothing. Exit 6 with the list.
NET_HOSTS='github.com raw.githubusercontent.com ghcr.io formulae.brew.sh pypi.org files.pythonhosted.org huggingface.co ffmpeg.org registry.npmjs.org claude.ai'
# Free space the way Finder counts it: with what macOS frees on demand (files
# kept in iCloud, old backups). df leaves that out and can read far too low.
free_gb() {
  local gb
  gb="$(/usr/bin/osascript -l JavaScript -e 'function run(a) { ObjC.import("Foundation"); var r = Ref();
    return $.NSURL.fileURLWithPath(a[0]).getResourceValueForKeyError(r, $.NSURLVolumeAvailableCapacityForImportantUsageKey, null)
      ? Math.floor(ObjC.unwrap(r[0]) / 1073741824) : -1 }' "$1" 2>/dev/null)"
  case "$gb" in ''|-1|*[!0-9]*) df -Pk "$1" 2>/dev/null | awk 'NR==2 {print int($4/1048576)}' ;; *) echo "$gb" ;; esac
}
disk_of() { df -P "$1" 2>/dev/null | awk 'NR==2 {print $1}'; }
is_admin() { id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin; }
icloud_desktop() { [ "$(defaults read com.apple.finder FXICloudDriveDesktop 2>/dev/null)" = 1 ]; }
# Only whether the site answers at all: headers, no page, any answer counts.
reach() { curl -sI -o /dev/null --connect-timeout 5 -m 10 "https://$1/" 2>/dev/null; }
node_found() { fresh 'printf "\n"; whence -p node' 2>/dev/null | tail -n 1; }
node_major() { fresh "node -p 'process.versions.node.split(\".\")[0]'" 2>/dev/null | tail -n 1; }
pre_dir=''
preflight() {
  local todo=() folder home gb hb out pair cmd formula path major prefix host bad='' n
  local synced="The Reels folder is inside a folder that syncs to the cloud (iCloud, Dropbox, Google Drive or OneDrive). The tools are about 35,000 files and must not sync. Move the Reels folder to your home folder, open it there in Claude and say install."
  folder="$(cd "$REELS" && pwd -P)" || folder="$REELS"
  home="$(cd "$HOME" && pwd -P)" || home="$HOME"
  # Only before the tools are installed: a kit that already works where it
  # is must not be stopped by an update.
  [ -x "$folder/.tools/run" ] || case "$folder" in
    "$home/Library/Mobile Documents"/*|"$home/Library/CloudStorage"/*) todo+=("$synced") ;;
    "$home/Desktop"/*|"$home/Documents"/*) ! icloud_desktop || todo+=("$synced") ;;
  esac
  if [ ! -d "$folder/.tools" ]; then # before a first install; a stopped one has used most of it already
    gb="$(free_gb "$folder")"; hb="$(free_gb "$HOME")"
    if [ "$(disk_of "$folder")" = "$(disk_of "$HOME")" ]; then
      [ "${gb:-99}" -ge 6 ] || todo+=("This Mac has $gb GB of free space and the install needs about 6 GB. Free up space (empty the Trash, delete old downloads or videos), then run setup again.")
    else
      [ "${gb:-99}" -ge 3 ] || todo+=("The disk the Reels folder is on has $gb GB of free space and the tools need about 3 GB there. Free up space on it, then run setup again.")
      [ "${hb:-99}" -ge 4 ] || todo+=("This Mac's own disk has $hb GB of free space and the install needs about 4 GB there. Free up space (empty the Trash, delete old downloads or videos), then run setup again.")
    fi
  fi
  if ! have_clt || ! have_brew; then
    is_admin || todo+=("This Mac account is not an administrator, and the install needs one. Log in as the Mac's owner, or ask them to make this account an administrator (System Settings, Users & Groups), then run setup again.")
  fi
  if have_brew; then
    [ -x "$BREW_BIN" ] && eval "$("$BREW_BIN" shellenv)"
    prefix="$(brew --prefix 2>/dev/null)"
    if [ ! -x "$folder/.tools/run" ] && [ ! -w "$prefix" ]; then
      todo+=("Homebrew on this Mac was installed by another user account, so this account cannot install tools with it. Log in as that user and run the install there, or send this line to the person who gave you the kit.")
    else
      for pair in node:node ffmpeg:ffmpeg whisper-cli:whisper.cpp uv:uv pkg-config:pkgconf; do
        cmd="${pair%%:*}"; formula="${pair#*:}"
        has "$cmd" || out="$(BREW_DRY=1 brew_install "$formula" 2>/dev/null)" || todo+=("$(printf '%s\n' "$out" | tail -n 1)")
      done
      brew list --versions libvidstab >/dev/null 2>&1 || out="$(BREW_DRY=1 brew_install libvidstab 2>/dev/null)" || todo+=("$(printf '%s\n' "$out" | tail -n 1)")
      [ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ] ||
        out="$(BREW_DRY=1 brew_install --cask google-chrome 2>/dev/null)" || todo+=("$(printf '%s\n' "$out" | tail -n 1)")
    fi
  fi
  if has node; then
    major="$(node_major)"; path="$(node_found)"
    if [ -n "$major" ] && [ "$major" -lt 22 ] 2>/dev/null; then
      case "$path" in
        */.nvm/*) n='Open Terminal, type: nvm install 22 && nvm alias default 22' ;;
        /opt/homebrew/*) n='Open Terminal, type: brew upgrade node' ;;
        *) n='Download the installer from nodejs.org (the button marked LTS), open it and click through' ;;
      esac
      todo+=("Node on this Mac is version $major and the kit needs 22 or newer. $n, then run setup again.")
    fi
  fi
  # setup runs npm only while the tools are being installed.
  if [ ! -x "$folder/.tools/run" ]; then
    for path in "$HOME/.npm" "$HOME/.npm/_cacache"; do
      [ ! -e "$path" ] || [ -O "$path" ] || { todo+=("The folder .npm in your home folder belongs to another account, which stops a tool from installing. Open Terminal, type: sudo chown -R $(id -un) ~/.npm and your Mac password, then run setup again."); break; }
    done
  fi
  # Only while the tools still have to be downloaded: a finished kit must not
  # be held up by a slow or closed network.
  if [ ! -x "$folder/.tools/run" ] && pre_dir="$(mktemp -d)"; then
    for host in $NET_HOSTS; do ( reach "$host" || : > "$pre_dir/$host" ) & done
    wait
    bad="$(ls "$pre_dir" | tr '\n' ' ')"; rm -rf "$pre_dir"; pre_dir=''
    n=0; for host in $bad; do n=$((n + 1)); done
    if [ "$n" -ge 8 ]; then
      todo+=("This Mac is not connected to the internet, or this network blocks almost everything the install downloads. Connect, or switch to another network (home Wi-Fi or a phone hotspot), then run setup again.")
    elif [ "$n" -gt 0 ]; then
      todo+=("This network does not let the Mac reach: ${bad% }. The install downloads from there. Switch to another network (home Wi-Fi or a phone hotspot; work and hotel networks often block these), then run setup again.")
    fi
  fi
  [ "${#todo[@]}" -gt 0 ] || return 0
  echo "This Mac is not ready for the kit yet. Nothing was installed. Fix these, then run setup again:"
  n=0; for out in "${todo[@]}"; do n=$((n + 1)); echo "$n. $out"; done
  return 6
}
preflight || exit 6
# A sleeping Mac stops the downloads: keep it awake while setup runs.
caffeinate -i -w $$ >/dev/null 2>&1 &

# Apple's developer tools give git, which plugin installs need.
if ! have_clt; then
  echo "Installing Apple's command line tools..."
  xcode-select --install >/dev/null 2>&1
  wait_for_clt || {
    echo "ACTION: A window asks to install the command line developer tools. Click Install, then Agree, and type your Mac password if asked. It takes 5 to 15 minutes. When the window says the software was installed, click Done and say done. If no such window is open, just say done."
    exit 3; }
fi

if ! have_brew; then
  ! command -v brew >/dev/null || echo "This Mac has an older Homebrew made for Intel Macs. Setup adds this Mac's own Homebrew beside it and leaves the old one as it is. From now on, brew in Terminal means the new one."
  if [ "$(uname -m)" = arm64 ]; then
    pkg_dir="$(mktemp -d)" && pkg="$pkg_dir/Homebrew.pkg" &&
      download -o "$pkg" https://github.com/Homebrew/brew/releases/latest/download/Homebrew.pkg || {
      echo "Could not download Homebrew. Check the internet connection, then run setup again."; exit 1; }
    verify_pkg "$pkg"; case $? in
      0) ;;
      2) echo "The downloaded Homebrew installer is signed by someone other than Homebrew's known signer. Nothing was installed. The kit may need an update: ask for a new copy of the kit."; exit 5 ;;
      *) echo "The downloaded Homebrew installer is not Homebrew's signed package. Nothing was installed. Run setup again later."; exit 1 ;;
    esac
    echo "Installing Homebrew. A window asks for this Mac's password..."
    osascript - "$ROOT_INSTALL" "$pkg" "$HOMEBREW_TEAM" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  do shell script "/bin/sh -c " & quoted form of item 1 of argv & " _ " & quoted form of item 2 of argv & " " & quoted form of item 3 of argv with prompt "Reels setup is installing Homebrew, the free tool installer." with administrator privileges
end run
APPLESCRIPT
    if ! have_brew; then
      open "$pkg"
      pkg_dir='' # keep the package for the open installer window
      echo "ACTION: A Homebrew installer window is open. Click Continue, Continue, Agree, then Install. Type your Mac password (or the Mac owner's name and password) and click Install Software. When it says the installation was successful, click Close and say done."
      exit 3
    fi
  elif [ -t 0 ]; then
    echo "Installing Homebrew (asks for this Mac's password)..."
    fetch_run https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh || { echo "Homebrew install failed. Fix the error above, then rerun setup.sh"; exit 1; }
  else
    echo 'ACTION: This Mac needs Homebrew installed from Terminal once. Press Command and Space, type Terminal, press Return. Copy this whole line, paste it into Terminal and press Return:'
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo 'ACTION: Type your Mac password when asked (nothing shows while you type) and press Return. Press Return again if asked. When Terminal says "Installation successful", close Terminal and say done.'
    exit 3
  fi
fi
[ -n "$pkg_dir" ] && { rm -rf "$pkg_dir"; pkg_dir=''; }
[ -x "$BREW_BIN" ] && eval "$("$BREW_BIN" shellenv)"
brew_path="$(command -v brew)" || { echo "Homebrew was not found. Install Homebrew, then rerun setup.sh"; exit 1; }
printf -v brew_quoted '%q' "$brew_path"
brew_line="eval \"\$("$brew_quoted" shellenv)\""
# A new Terminal must find this same Homebrew, not an older one beside it.
# On a kit that is already installed, only when it finds none at all.
if [ -x "$REELS/.tools/run" ]; then profile_add brew "$brew_line"
else [ "$(fresh 'printf "\n"; whence -p brew' 2>/dev/null | tail -n 1)" = "$brew_path" ] || grep -qsF "$brew_line" "$HOME/.zprofile" || echo "$brew_line" >> "$HOME/.zprofile"
fi
# Use the same PATH a new Terminal (and the check) uses, so what is found is what runs.
login_path="$(fresh 'printf "\n%s" "$PATH"' 2>/dev/null | tail -n 1)" && [ -n "$login_path" ] && export PATH="$login_path:$PATH"

ensure() { # ensure <command> <formula>: install the formula only if the command is missing
  has "$1" && return
  brew_install "$2" || return 1
  has "$1" || { printf '%s is installed in a version without %s. Update it yourself (brew upgrade %s), then rerun setup.sh.\n' "$2" "$1" "$2"; return 1; }
}

ensure node node || exit 1
fresh "node -e 'process.exit(+process.versions.node.split(\".\")[0] < 22 ? 1 : 0)'" >/dev/null 2>&1 || { echo "Node is unavailable or older than 22. Update Node yourself, then rerun setup.sh"; exit 1; }
ensure ffmpeg ffmpeg || exit 1
ensure whisper-cli whisper.cpp || exit 1
[ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ] || brew_install --cask google-chrome || exit 1

if ! resolve_claude; then # a real program, not an alias from an old install
  fetch_run https://claude.ai/install.sh || { echo "Claude Code install failed. Fix the error above, then rerun setup.sh"; exit 1; }
fi
export PATH="$HOME/.local/bin:$PATH"
profile_add claude 'export PATH="$HOME/.local/bin:$PATH"'

mkdir -p "$REELS/reels" "$REELS/scripts" "$REELS/setup/best-reels" "$REELS/setup/audience" "$REELS/setup/brand" "$REELS/setup/references" "$REELS/sources" || exit 1
REELS="$(cd "$REELS" && pwd -P)"
[ -f "$REELS/CLAUDE.md" ] || cp "$KIT/CLAUDE.md" "$REELS/CLAUDE.md" || { echo "The kit's CLAUDE.md is missing. Download the kit again."; exit 1; }

cd "$REELS" || exit 1
resolve_claude || { echo "Claude Code was not found in a new Terminal. Fix its installation, then rerun setup.sh"; exit 1; }
# The plugin steps need a recent Claude Code: an older one cannot fetch a
# marketplace at an exact commit ("Remote branch <commit> not found"), and
# the Claude app updating itself does not update this command. So every
# run updates it first. A failed update stops nothing here: a plugin step
# that then fails says what to do (no internet is the usual cause, since a
# copy that may not update itself is replaced by a current one).
# Setup runs inside a Claude session, where an older Claude Code refuses
# to start at all ("cannot be launched inside another Claude Code
# session"); an update is not a session, so it runs without that mark.
claude_update() {
  echo "Updating Claude Code..."
  # Homebrew's copy only says "brew upgrade claude-code" and reports
  # success with nothing changed, so it counts as one that cannot update.
  if case "$(readlink -f "$claude_bin" 2>/dev/null)" in
       */Caskroom/*) false ;;
       *) env -u CLAUDECODE "$claude_bin" update ;;
     esac; then
    resolve_claude || { echo "Claude Code was not found in a new Terminal. Fix its installation, then rerun setup.sh"; exit 1; }
    return 0
  fi
  # Nor can a copy npm put in a folder only an administrator may change
  # ("Insufficient permissions"). Anthropic's own installer
  # puts a current one in ~/.local/bin; that folder goes first on the PATH.
  echo "Installing a current Claude Code beside it..."
  if (unset CLAUDECODE; fetch_run https://claude.ai/install.sh) && [ -x "$HOME/.local/bin/claude" ]; then
    claude_bin="$HOME/.local/bin/claude"
    grep -qsxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zprofile" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zprofile"
    return 0
  fi
  echo "Claude Code could not update itself. Carrying on with the version on this Mac."
}
claude_update
claude_step() { # claude_step "<what>" <claude arguments...>
  local what="$1" ver; shift
  "$claude_bin" "$@" && return 0
  ver="$(env -u CLAUDECODE "$claude_bin" --version 2>/dev/null)"
  echo "$what failed with Claude Code ${ver%% *}. The error is above. Check the internet connection, then rerun setup.sh"
  return 1
}
claude_step "Instagram skills marketplace setup" plugin marketplace add --scope project "$INSTAGRAM_MARKETPLACE" || exit 1
if plugin_field instagram-agent@instagram-agent-skill id >/dev/null; then
  claude_step "Instagram skills update" plugin update --scope project instagram-agent@instagram-agent-skill || exit 1
else
  claude_step "Instagram skills install" plugin install --scope project instagram-agent@instagram-agent-skill || exit 1
fi
claude_step "HyperFrames marketplace setup" plugin marketplace add --scope project "$HYPERFRAMES_MARKETPLACE" || exit 1
if plugin_field hyperframes@hyperframes id >/dev/null; then
  claude_step "HyperFrames update" plugin update --scope project hyperframes@hyperframes || exit 1
else
  claude_step "HyperFrames install" plugin install --scope project hyperframes@hyperframes || exit 1
fi
hf="$(plugin_field hyperframes@hyperframes installPath)" || { echo "HyperFrames was not found. Fix its installation, then rerun setup.sh"; exit 1; }
fence write || { echo "Could not update this folder's Claude settings (.claude/settings.json). Fix or remove that file, then rerun setup.sh"; exit 1; }
node "$hf/skills/hyperframes/scripts/plugin-cli.mjs" telemetry disable || { echo "Could not turn off HyperFrames usage reporting. Fix the error above, then rerun setup.sh"; exit 1; }
doctor_output="$(node "$hf/skills/hyperframes/scripts/plugin-cli.mjs" doctor --json)"; doctor_status=$?
printf '%s\n' "$doctor_output"
[ "$doctor_status" -eq 0 ] || { echo "HyperFrames check failed (exit $doctor_status). Fix the error above, then rerun setup.sh"; exit 1; }
# Doctor JSON reports optional failures without a nonzero exit.
printf '%s' "$doctor_output" | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    let report; try { report = JSON.parse(s); } catch { console.error("Invalid doctor JSON"); process.exit(1); }
    if (!Array.isArray(report.checks)) { console.error("Missing doctor checks"); process.exit(1); }
    const required = ["Node.js", "FFmpeg", "FFprobe", "Chrome"];
    const failed = required.filter(name => {
      const matches = report.checks.filter(check => check.name === name);
      return matches.length !== 1 || matches[0].ok !== true;
    });
    if (failed.length) { console.error("Required doctor checks failed or missing: " + failed.join(", ")); process.exit(1); }
  });' || { echo "HyperFrames required checks failed (exit $doctor_status). Fix the errors above, then rerun setup.sh"; exit 1; }

# Video tools stay inside the Reels folder.
echo; echo "== Video tools =="
[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || { echo "The video tools need a Mac with Apple silicon (M1 or newer)."; exit 1; }
TOOLS="$REELS/.tools"
export UV_PYTHON_INSTALL_DIR="$TOOLS/python" UV_CACHE_DIR="$TOOLS/cache" UV_PYTHON_PREFERENCE=only-managed
export TORCH_HOME="$TOOLS/models" HF_HOME="$TOOLS/models" U2NET_HOME="$TOOLS/models"
mkdir -p "$TOOLS" || { echo "Could not create the video tools folder. Run setup again."; exit 1; }
clean_video_temp
RUN="$TOOLS/.run.partial"
cp "$KIT/tools/run" "$RUN" && chmod 755 "$RUN" || { echo "Could not prepare the video tools launcher. If this folder has no tools folder, copy it from the kit, then run setup again."; exit 1; }
ensure uv uv || exit 1
uv_list="$(uv python list 3.12.13 --only-downloads --no-config 2>/dev/null)" &&
  [ -n "$uv_list" ] && uv venv --help --no-config 2>/dev/null | grep -- --clear >/dev/null || {
  echo "uv is installed in a version without the required Python 3.12.13 or venv --clear support. Update uv yourself, then rerun setup.sh."
  exit 1
}
brew list --versions libvidstab >/dev/null 2>&1 || brew_install libvidstab || exit 1
has pkg-config || brew_install pkgconf || exit 1
python_tools_ok() {
  [ -x "$TOOLS/venv/bin/python" ] && [ -f "$TOOLS/venv/pyvenv.cfg" ] || return 1
  local home python_root test
  home="$(sed -n 's/^home[[:space:]]*=[[:space:]]*//p' "$TOOLS/venv/pyvenv.cfg")"
  home="$(cd "$home" 2>/dev/null && pwd -P)" || return 1
  python_root="$(cd "$TOOLS/python" 2>/dev/null && pwd -P)" || return 1
  case "$home" in "$python_root/"*) ;; *) return 1 ;; esac
  for test in "$scene_test" "$auto_test" "$color_test" "$rembg_test" "$demucs_test" "$librosa_test"; do
    video_ok "$test" "$RUN" packages || return 1
  done
}
if ! python_tools_ok; then
  uv venv --no-config --clear --python 3.12.13 "$TOOLS/venv" &&
    VIRTUAL_ENV="$TOOLS/venv" uv pip install --no-config --exclude-newer 2026-11-13T00:00:00Z 'scenedetect==0.7.3' 'color-matcher==0.6.0' 'librosa==1.0.1' 'auto-editor==29.3.1' 'demucs==4.1.0' 'rembg[cpu,cli]==2.0.87' || {
      echo "Python video tools install failed. Run setup again."; exit 1; }
  auto_dir="$("$TOOLS/venv/bin/python" -c 'import auto_editor,os;print(os.path.dirname(auto_editor.__file__))')" || { echo "Auto-Editor package check failed. Run setup again."; exit 1; }
  auto_bin="$auto_dir/bin/auto-editor"
  mkdir -p "$(dirname "$auto_bin")" || { echo "Could not create the Auto-Editor folder. Run setup again."; exit 1; }
  fetch_pinned https://github.com/WyattBlue/auto-editor/releases/download/29.3.1/auto-editor-macos-arm64 "$AUTO_SHA" "$auto_bin" Auto-Editor || exit 1
  chmod 755 "$auto_bin" && python_tools_ok || { echo "Python video tools check failed. Run setup again."; exit 1; }
fi
rembg_model="$TOOLS/models/models/isnet-general-use/isnet-general-use.onnx"
if ! video_ok "$rembg_test" "$RUN"; then
  mkdir -p "$(dirname "$rembg_model")" || { echo "Could not create the rembg model folder. Run setup again."; exit 1; }
  fetch_pinned https://github.com/danielgatis/rembg/releases/download/v0.0.0/isnet-general-use.onnx "$REMBG_SHA" "$rembg_model" rembg || exit 1
  work="$(mktemp -d "$TOOLS/rembg-build.XXXXXX")" || { echo "Could not create the rembg test folder. Run setup again."; exit 1; }
  "$RUN" python -c 'from PIL import Image; import sys; Image.new("RGB", (8, 8), "white").save(sys.argv[1])' "$work/in.png" &&
    "$RUN" rembg i -m isnet-general-use "$work/in.png" "$work/out.png" &&
    [ -s "$work/out.png" ] && video_ok "$rembg_test" "$RUN" || {
      rm -rf "$work"; echo "rembg model check failed. Run setup again."; exit 1; }
  rm -rf "$work"
fi
demucs_model_setup() {
  local cache="$TOOLS/models/hub/models--adefossez--HTDemucs"
  local model="$TOOLS/models/hub/models--adefossez--HTDemucs/blobs/$DEMUCS_SHA"
  local work
  rm -rf "$cache"
  "$RUN" env HF_HUB_OFFLINE=0 "$TOOLS/venv/bin/python" -c "from huggingface_hub import hf_hub_download as d; [d('adefossez/HTDemucs', f, revision='$DEMUCS_REV') for f in ('htdemucs.yaml', '955717e8.safetensors')]" || { echo "Demucs model download failed. Check the internet connection, then run setup again."; return 1; }
  sha_ok "$model" "$DEMUCS_SHA" &&
    sha_ok "$cache/snapshots/$DEMUCS_REV/htdemucs.yaml" "$DEMUCS_YAML_SHA" &&
    [ -f "$cache/snapshots/$DEMUCS_REV/955717e8.safetensors" ] || {
    rm -rf "$cache"
    echo "Demucs: The download did not match the expected file. Nothing was installed. Run setup again later."
    return 1
  }
  mkdir -p "$cache/refs" && printf '%s' "$DEMUCS_REV" > "$cache/refs/main" || { echo "Could not save the Demucs model reference. Run setup again."; return 1; }
  work="$(mktemp -d "$TOOLS/demucs.XXXXXX")" || { echo "Could not create the Demucs test folder. Run setup again."; return 1; }
  "$TOOLS/venv/bin/python" -c 'import wave,sys; w=wave.open(sys.argv[1],"wb"); w.setparams((1,2,44100,44100,"NONE","not compressed")); w.writeframes(bytes(88200)); w.close()' "$work/input.wav" || { rm -rf "$work"; echo "Could not create the Demucs test audio. Run setup again."; return 1; }
  rm -rf "$TOOLS/models/hub/checkpoints" "$TOOLS/models/checkpoints" || { rm -rf "$work" "$cache"; echo "Could not clear the Demucs checkpoint folders. Run setup again."; return 1; }
  local separation_status=0
  "$RUN" env HF_HUB_OFFLINE=1 demucs --two-stems vocals -o "$work/out" "$work/input.wav" || separation_status=$?
  if [ -n "$(find "$TOOLS/models/hub/checkpoints" "$TOOLS/models/checkpoints" -type f -print -quit 2>/dev/null)" ]; then
    rm -rf "$work" "$cache" "$TOOLS/models/hub/checkpoints" "$TOOLS/models/checkpoints"
    echo "Demucs did not load the pinned model and tried to download another one."
    return 1
  fi
  [ "$separation_status" -eq 0 ] || { rm -rf "$work"; echo "Demucs model setup failed. Run setup again."; return 1; }
  rm -rf "$work"
  video_ok "$demucs_test" "$RUN" || { echo "Demucs check failed. Run setup again."; return 1; }
}
if ! video_ok "$demucs_test" "$RUN"; then
  demucs_model_setup || exit 1
fi
mkdir -p "$TOOLS/ffmpeg-vidstab/bin" && ln -sf ffmpeg "$TOOLS/ffmpeg-vidstab/bin/ffmpeg-vidstab" || { echo "Could not create the vid.stab launcher. Run setup again."; exit 1; }
vidstab_build() { # builds into a new folder and swaps it in only once it passes
  local work
  work="$(mktemp -d "$TOOLS/ffmpeg-build.XXXXXX")" || { echo "Could not create the vid.stab build folder."; return 1; }
  fetch_pinned "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" "$FFMPEG_SHA" "$work/source.tar.xz" vid.stab || { rm -rf "$work"; return 1; }
  # Only libvidstab from Homebrew: a build that picks up other Homebrew
  # libraries stops starting once Homebrew removes or upgrades them.
  (cd "$work" && tar -xf source.tar.xz && cd "ffmpeg-$FFMPEG_VERSION" && PKG_CONFIG_LIBDIR="$(brew --prefix libvidstab)/lib/pkgconfig" PKG_CONFIG_PATH='' ./configure --prefix="$work/prefix" --disable-autodetect --enable-gpl --enable-libvidstab --enable-videotoolbox --enable-audiotoolbox --enable-zlib --disable-doc --disable-ffplay --disable-network --disable-debug && make -j"$(sysctl -n hw.ncpu)" && make install) > "$TOOLS/ffmpeg-build.log" 2>&1 || { rm -rf "$work"; echo "vid.stab build failed."; tail -n 20 "$TOOLS/ffmpeg-build.log"; return 1; }
  rm -f "$TOOLS/ffmpeg-build.log"
  ln -sf ffmpeg "$work/prefix/bin/ffmpeg-vidstab" || { rm -rf "$work"; return 1; }
  rm -rf "$TOOLS/ffmpeg-vidstab.old"
  # The launcher folder always exists (made above), so there is always one to put back.
  mv "$TOOLS/ffmpeg-vidstab" "$TOOLS/ffmpeg-vidstab.old" && mv "$work/prefix" "$TOOLS/ffmpeg-vidstab" || { rm -rf "$work"; [ -e "$TOOLS/ffmpeg-vidstab" ] || mv "$TOOLS/ffmpeg-vidstab.old" "$TOOLS/ffmpeg-vidstab"; return 1; }
  rm -rf "$work"
  if video_ok "$vidstab_current" "$RUN"; then rm -rf "$TOOLS/ffmpeg-vidstab.old"; return 0; fi
  echo "vid.stab check failed."
  rm -rf "$TOOLS/ffmpeg-vidstab"; mv "$TOOLS/ffmpeg-vidstab.old" "$TOOLS/ffmpeg-vidstab"
  return 1
}
# A setup stopped inside vidstab_build's swap left the previous build beside
# it: keep whichever works.
if [ -d "$TOOLS/ffmpeg-vidstab.old" ]; then
  if video_ok "$vidstab_test" "$RUN"; then rm -rf "$TOOLS/ffmpeg-vidstab.old"
  else rm -rf "$TOOLS/ffmpeg-vidstab" && mv "$TOOLS/ffmpeg-vidstab.old" "$TOOLS/ffmpeg-vidstab"; fi
fi
if ! video_ok "$vidstab_current" "$RUN"; then
  # A kit that already steadies keeps its build when the new one cannot be
  # made (an update must not stop a working kit); setup tries again next run.
  if video_ok "$vidstab_test" "$RUN"; then
    vidstab_build || echo "vid.stab could not be updated. The version on this Mac stays until setup runs again."
  else
    vidstab_build || { echo "Run setup again."; exit 1; }
  fi
fi
if ! video_ok "$rife_test" "$RUN"; then
  work="$(mktemp -d "$TOOLS/rife-build.XXXXXX")" || { echo "Could not create the RIFE install folder. Run setup again."; exit 1; }
  fetch_pinned https://github.com/nihui/rife-ncnn-vulkan/releases/download/20221029/rife-ncnn-vulkan-20221029-macos.zip 4a63a1f3c9c715773c57d2ee51df1b315ed20cd6c63103e45c483ecc4400b595 "$work/source.zip" RIFE || { rm -rf "$work"; exit 1; }
  unzip -q "$work/source.zip" '*/rife-ncnn-vulkan' '*/rife-v4.6/*' -d "$work" &&
    mkdir -p "$work/staged" && cp -R "$work/rife-ncnn-vulkan-20221029-macos/rife-ncnn-vulkan" "$work/rife-ncnn-vulkan-20221029-macos/rife-v4.6" "$work/staged/" && chmod 755 "$work/staged/rife-ncnn-vulkan" && rm -rf "$TOOLS/rife" && mv "$work/staged" "$TOOLS/rife" || { rm -rf "$work"; echo "RIFE install failed. Run setup again."; exit 1; }
  rm -rf "$work"
  video_ok "$rife_test" "$RUN" || { echo "RIFE check failed. Run setup again."; exit 1; }
fi
if ! video_ok "$esrgan_test" "$RUN"; then
  work="$(mktemp -d "$TOOLS/realesrgan-build.XXXXXX")" || { echo "Could not create the Real-ESRGAN install folder. Run setup again."; exit 1; }
  fetch_pinned https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip e0ad05580abfeb25f8d8fb55aaf7bedf552c375b5b4d9bd3c8d59764d2cc333a "$work/source.zip" Real-ESRGAN || { rm -rf "$work"; exit 1; }
  unzip -q "$work/source.zip" 'realesrgan-ncnn-vulkan' 'models/*' -d "$work" && mkdir -p "$work/staged" && cp -R "$work/realesrgan-ncnn-vulkan" "$work/models" "$work/staged/" && chmod 755 "$work/staged/realesrgan-ncnn-vulkan" && rm -rf "$TOOLS/realesrgan" && mv "$work/staged" "$TOOLS/realesrgan" || { rm -rf "$work"; echo "Real-ESRGAN install failed. Run setup again."; exit 1; }
  rm -rf "$work"
  video_ok "$esrgan_test" "$RUN" || { echo "Real-ESRGAN check failed. Run setup again."; exit 1; }
fi
publish_video_tools() {
  local test
  for test in "$scene_test" "$auto_test" "$vidstab_test" "$color_test" "$rembg_test" "$rife_test" "$esrgan_test" "$demucs_test" "$librosa_test"; do
    video_ok "$test" "$RUN" || { rm -f "$TOOLS/run"; echo "Video tools final check failed. Run setup again."; return 1; }
  done
  mv -f "$RUN" "$TOOLS/run" || { echo "Could not install the video tools launcher. Run setup again."; return 1; }
  rm -rf "$TOOLS/cache"
}
publish_video_tools || exit 1

# Palmier Pro: the editor with a live preview. Its own installer file is
# downloaded, checked against the pinned hash and Palmier's signature, then
# copied to Applications. An app that is already there is left as it is.
# A failure here never stops setup: reels are edited with HyperFrames until
# a later run installs it.
palmier_setup() {
  local app work dest
  if ! app="$(palmier_app)"; then
    work="$(mktemp -d "$TOOLS/palmier.XXXXXX")" || { echo "Could not create the Palmier Pro install folder."; return 1; }
    fetch_pinned "$PALMIER_URL" "$PALMIER_SHA" "$work/PalmierPro.dmg" "Palmier Pro" || { rm -rf "$work"; return 1; }
    mkdir "$work/mnt" && hdiutil attach -nobrowse -readonly -quiet -mountpoint "$work/mnt" "$work/PalmierPro.dmg" || {
      palmier_drop "$work"; echo "Could not open the Palmier Pro download."; return 1; }
    if ! palmier_signed "$work/mnt/PalmierPro.app"; then
      palmier_drop "$work"
      echo "The downloaded Palmier Pro could not be verified as Palmier's signed app. Nothing was installed."; return 1
    fi
    dest="${PALMIER_APPS_DIR:-/Applications}"
    [ -d "$dest" ] && [ -w "$dest" ] || dest="$HOME/Applications"
    # Copy under another name first: an interrupted copy must never look like the app.
    mkdir -p "$dest" && rm -rf "$dest/.PalmierPro.app.partial" && ditto "$work/mnt/PalmierPro.app" "$dest/.PalmierPro.app.partial" && mv "$dest/.PalmierPro.app.partial" "$dest/PalmierPro.app" || {
      rm -rf "$dest/.PalmierPro.app.partial"; palmier_drop "$work"
      echo "Could not copy Palmier Pro to Applications."; return 1; }
    palmier_drop "$work"
    app="$dest/PalmierPro.app"
  fi
  palmier_signed "$app" || { echo "The Palmier Pro already in $(dirname "$app") could not be verified as Palmier's own app, so the kit leaves it alone and does not use it."; return 1; }
  if ! palmier_skills_ok; then
    work="$(mktemp -d "$TOOLS/palmier-skills.XXXXXX")" || { echo "Could not create the Palmier guides folder."; return 1; }
    (cd "$work" && git init -q && git fetch -q --depth 1 https://github.com/palmier-io/palmier-skills.git "$PALMIER_SKILLS" && git checkout -q FETCH_HEAD && [ "$(git rev-parse HEAD)" = "$PALMIER_SKILLS" ]) || {
      rm -rf "$work"; echo "Palmier editing guides download failed. Check the internet connection."; return 1; }
    rm -rf "$work/.git" && echo "$PALMIER_SKILLS" > "$work/.commit" && rm -rf "$TOOLS/palmier-skills" && mv "$work" "$TOOLS/palmier-skills" || {
      rm -rf "$work"; echo "Could not install the Palmier editing guides."; return 1; }
  fi
}
if palmier_fits; then
  palmier_setup || echo "Palmier Pro is not ready yet. Reels are edited with HyperFrames until setup runs again and installs it."
fi

update_done
echo; echo "== Check =="; check; code=$?
[ $code -eq 0 ] && echo "Done. Quit the Claude app (Command Q) and open it again, then start a new Code session in this Reels folder and say: set me up"
exit $code
