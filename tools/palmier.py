#!/usr/bin/env python3
"""Talks to the Palmier Pro app on this Mac (its local agent port).

  palmier.py wait                      open Palmier, print READY when it answers
  palmier.py list                      every tool with a one-line description
  palmier.py schema <tool> [<tool>..]  full description and parameters
  palmier.py call <tool> '<json>' [<image path>]
                                       run a tool; frames it returns are saved
                                       as <image path>.png, <image path>-1.png ...
"""
import base64, json, os, socket, subprocess, sys, tempfile, time, urllib.error, urllib.request

URL = os.environ.get("PALMIER_URL", "http://127.0.0.1:19789/mcp")
CLOSED = "Palmier Pro is not open. Run: .tools/run python tools/palmier.py wait"


def post(body, sid=None, timeout=900):
    head = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    if sid:
        head["Mcp-Session-Id"] = sid
    req = urllib.request.Request(URL, json.dumps(body).encode(), head)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read().decode(errors="replace")
        sid = r.headers.get("Mcp-Session-Id") or sid
    if not raw.lstrip().startswith("{"):  # event stream: the last data line is the answer
        data = [l[5:].strip() for l in raw.splitlines() if l.startswith("data:") and l[5:].strip()]
        raw = data[-1] if data else ""
    return (json.loads(raw) if raw.strip() else None), sid


def session():  # a stuck app must fail in seconds, not hold the session open
    _, sid = post({"jsonrpc": "2.0", "id": 0, "method": "initialize", "params": {
        "protocolVersion": "2025-06-18", "capabilities": {},
        "clientInfo": {"name": "reels-kit", "version": "1"}}}, timeout=5)
    try:
        post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid, timeout=5)
    except Exception:
        pass
    return sid


def close(sid):  # best effort: do not leave a session open in the app per call
    if not sid:
        return
    try:
        req = urllib.request.Request(URL, method="DELETE", headers={"Mcp-Session-Id": sid})
        urllib.request.urlopen(req, timeout=5).close()
    except Exception:
        pass


def tools():
    sid = session()
    try:
        r, _ = post({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}, sid)
    finally:
        close(sid)
    r = r or {}
    if "result" not in r:
        print("Palmier Pro could not list its tools: %s" % json.dumps(r.get("error") or "empty answer"))
        sys.exit(1)
    return r["result"]["tools"]


def wait():
    try:
        close(session())
    except Exception:
        subprocess.run(["open", "-g", "-a", "PalmierPro"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(30):
        try:
            close(session())
            print("READY")
            return 0
        except Exception:
            time.sleep(1)
    print("Palmier Pro did not answer. If its window shows a sign-in screen, "
          "click Skip or sign in, then run wait again. If the app is missing, run setup again.")
    return 1


def call(name, args, image):
    sid = session()
    try:
        r, _ = post({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                     "params": {"name": name, "arguments": args}}, sid)
    finally:
        close(sid)
    r = r or {}
    if "error" in r:
        print(json.dumps(r["error"]))
        return 1
    res = r.get("result") or {}
    n = 0
    for c in res.get("content", []):
        if c.get("type") == "text":
            print(c["text"])
        elif c.get("type") == "image":
            ext = ".jpg" if "jp" in c.get("mimeType", "") else ".png"
            out = image + ("-%d" % n if n else "") + ext
            os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
            with open(out, "wb") as f:
                f.write(base64.b64decode(c["data"]))
            n += 1
            print("[image saved] " + out)
        else:
            print(json.dumps(c)[:2000])
    if not res.get("content"):
        print(json.dumps(res)[:4000])
    return 1 if res.get("isError") else 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "wait":
        return wait()
    if cmd == "list":
        for t in tools():
            print(t["name"] + " | " + " ".join((t.get("description") or "").split())[:160])
        return 0
    if cmd == "schema" and len(argv) > 2:
        found = [t for t in tools() if t["name"] in argv[2:]]
        for t in found:
            print(json.dumps(t, indent=1))
        return 0 if len(found) == len(set(argv[2:])) else 1
    if cmd == "call" and len(argv) > 2:
        try:
            args = json.loads(argv[3]) if len(argv) > 3 else {}
        except ValueError as e:
            print("The tool input is not valid JSON: %s" % e)
            return 2
        image = argv[4] if len(argv) > 4 else os.path.join(tempfile.gettempdir(), "palmier-frame")
        return call(argv[2], args, image)
    print(__doc__)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except urllib.error.HTTPError as e:
        print("Palmier Pro refused the request (%s): %s" % (e.code, e.read().decode(errors="replace")[:500]))
        sys.exit(1)
    except (TimeoutError, socket.timeout):
        print("Palmier Pro is not answering. Check its window, then run: .tools/run python tools/palmier.py wait")
        sys.exit(3)
    except (urllib.error.URLError, ConnectionError) as e:
        if isinstance(getattr(e, "reason", None), (TimeoutError, socket.timeout)):
            print("Palmier Pro is not answering. Check its window, then run: .tools/run python tools/palmier.py wait")
        else:
            print(CLOSED)
        sys.exit(3)
    except Exception as e:
        print("Palmier Pro gave an answer the kit could not read: %s" % e)
        sys.exit(1)
