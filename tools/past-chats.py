#!/usr/bin/env python3
"""Print what Claude saved about a folder and what the person typed there.

Usage: past-chats.py "<folder path>" [--since YYYY-MM-DD]

The Claude app keeps each folder's chats and saved memory under
~/.claude/projects/<folder path with every other character as "-">/.
This prints the memory files and only the messages the person typed (no
tool output, no replies): the folder's own chats newest first, then chats
started in its subfolders. It reads; it changes nothing.
"""
import glob
import json
import os
import re
import sys

LIMIT = 60000  # characters printed in total
PER_MESSAGE = 600
PER_MEMORY_FILE = 4000
SKIP_STARTS = (
    "<", "Base directory for this skill", "Stop hook feedback",
    "[Request interrupted", "This session is being continued",
    "Caveat: The messages below",
)


def project_dirs(folder):
    """Chat folders for this folder, then for its subfolders."""
    root = os.path.join(
        os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"),
        "projects",
    )
    folder = os.path.expanduser(folder)
    paths = {os.path.abspath(folder), os.path.realpath(folder)}
    exact, subs = [], []
    for p in paths:
        name = re.sub(r"[^A-Za-z0-9]", "-", p)
        d = os.path.join(root, name)
        if os.path.isdir(d) and d not in exact:
            exact.append(d)
        # Chats started in a subfolder are stored under a longer name.
        # A neighbour such as "<folder> Old" has one too, so check the
        # folder recorded inside the chats.
        for sub in sorted(glob.glob(os.path.join(root, glob.escape(name) + "-*"))):
            if sub not in subs and inside(recorded_cwd(sub), paths):
                subs.append(sub)
    if exact or subs:
        return exact, subs
    # Very long paths are stored under a shortened name: match on the
    # folder recorded inside the chats instead.
    for d in glob.glob(os.path.join(root, "*")):
        cwd = recorded_cwd(d)
        if cwd in paths:
            exact.append(d)
        elif inside(cwd, paths):
            subs.append(d)
    return exact, subs


def recorded_cwd(project_dir):
    chats = sorted(glob.glob(os.path.join(project_dir, "*.jsonl")),
                   key=mtime, reverse=True)
    for chat in chats:
        cwd = first_cwd(chat)
        if cwd:
            return cwd
    return None


def inside(cwd, paths):
    return bool(cwd) and any(
        cwd == p or cwd.startswith(p.rstrip(os.sep) + os.sep) for p in paths)


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0


def day_of(path):
    import datetime
    return datetime.date.fromtimestamp(mtime(path)).isoformat()


def first_cwd(chat):
    try:
        with open(chat, errors="replace") as f:
            for n, line in enumerate(f):
                if n > 200:
                    break
                try:
                    cwd = json.loads(line).get("cwd")
                except ValueError:
                    continue
                if cwd:
                    return cwd
    except OSError:
        pass
    return None


def typed(chat, since):
    out = []
    try:
        f = open(chat, errors="replace")
    except OSError:
        return out
    with f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("type") != "user" or d.get("isMeta") or d.get("isSidechain"):
                continue
            c = (d.get("message") or {}).get("content")
            if isinstance(c, list):
                # Tool output is not typed. A screenshot with a note is.
                if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c):
                    continue
                c = " ".join(b.get("text", "") for b in c
                             if isinstance(b, dict) and b.get("type") == "text")
            if not isinstance(c, str):
                continue
            c = c.strip()
            day = str(d.get("timestamp") or "")[:10]
            if not c or c.startswith(SKIP_STARTS) or (since and day and day < since):
                continue
            out.append((day, c))
    return out


def main(argv):
    if len(argv) < 2 or argv[1].startswith("-"):
        print(__doc__.strip())
        return 2
    folder = argv[1]
    since = ""
    if len(argv) > 2:
        if len(argv) != 4 or argv[2] != "--since" \
                or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", argv[3]):
            print('Usage: past-chats.py "<folder path>" [--since 2026-01-31]')
            return 2
        since = argv[3]
    exact, subs = project_dirs(folder)
    dirs = exact + subs
    left = LIMIT
    memory = []
    for d in dirs:
        for m in sorted(glob.glob(os.path.join(d, "memory", "*.md"))):
            if os.path.isfile(m) and not os.path.islink(m) \
                    and not (since and day_of(m) < since):
                memory.append(m)
    # The folder's own chats come first, so chats from its subfolders
    # cannot push them past the limit.
    chats = [c for group in (exact, subs) for c in sorted(
        (c for d in group for c in glob.glob(os.path.join(d, "*.jsonl"))),
        key=mtime, reverse=True)]
    blocks = [(c, typed(c, since)) for c in chats]
    blocks = [(c, msgs) for c, msgs in blocks if msgs]
    if not memory and not blocks:
        print("No saved chats or memory found for " + folder
              + (" since " + since if since else ""))
        return 0
    if memory:
        print("# What Claude saved about this folder")
        for m in memory:
            if left <= 0:
                print("\n(more saved files not shown)")
                break
            try:
                text = open(m, errors="replace").read().strip()
            except OSError:
                continue
            if len(text) > PER_MEMORY_FILE:
                text = text[:PER_MEMORY_FILE] + " (cut)"
            print("\n## " + os.path.basename(m) + "\n" + text)
            left -= len(text)
    if blocks:
        print("\n# What the person typed in past chats (newest chat first"
              + (", then chats started in %d subfolder(s)" % len(subs) if subs else "")
              + ")")
    for c, msgs in blocks:
        if left <= 0:
            print("\n(older chats not shown)")
            break
        print("\n## chat from " + (msgs[0][0] or "unknown date"))
        for day, text in msgs:
            if len(text) > PER_MESSAGE:
                text = text[:PER_MESSAGE] + " (cut)"
            print("- " + text.replace("\n", "\n  "))
            left -= len(text)
            if left <= 0:
                break
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
