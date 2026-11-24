# Reels kit

An Instagram manager and reel editor that runs in the Claude app. It finds
what is working on pages like yours, brings you reel ideas with hooks, turns
your talking-to-camera footage, b-roll and photos into finished reels, and
learns from your feedback. Scripts start from what you want to say: you
tell Claude in a voice note or rough notes, and it writes the script in
your words. The kit uses the
Instagram skills (github.com/Jakeschincariol/instagram-agent-skill),
HyperFrames (github.com/heygen-com/hyperframes) and a script method
adapted from Ekos Labs (github.com/Ekos-Labs/skills), which is included
in the kit as text. On a Mac with macOS 26
or newer it edits in Palmier Pro (github.com/palmier-io/palmier-pro), a
free video editor app where you watch every change live and nothing is
rendered until the reel is ready. You need a paid Claude plan (Pro or
higher), the Claude app, and a Mac with an Apple chip (M1 or newer) on
macOS 15 or newer. On an older macOS the install stops and asks you to
update macOS first, because the tools would otherwise be built from
scratch for hours.

## Install

1. Make a new, empty folder called `Reels` in your home folder (in
   Finder: Go, Home, then File, New Folder). It must stay where it is
   after step 4. Not in iCloud Drive, Dropbox or Google Drive, and not
   on an external disk: the tools are about 35,000 files that must not
   sync.
2. Open the Claude app and click **Code**.
3. Under the message box, click the folder button and choose the `Reels`
   folder. If Claude asks whether you trust this folder, say yes. If your Mac
   asks whether Claude may access that folder, click Allow.
4. Paste this and press Return:

   ```
   Download
   https://github.com/frederikhejlskov/reels-kit/raw/main/setup.sh
   into this folder, run "bash setup.sh --update", then read CLAUDE.md
   and do what its Install section says.
   ```

   Claude fetches the kit and first checks your Mac: free space, macOS,
   the network and the tools already on it. If something is not ready,
   you get one list of what to fix before anything is installed. Then
   Claude installs the free tools and tells you what to click. Windows
   may ask you to install command line developer tools (click Install,
   then Agree) or for your Mac password (type it, click OK). It can take
   up to 40 minutes. Allow about 6 GB free during install and about 2 GB
   afterwards, plus room for your footage.
5. When Claude says "All set", quit the Claude app (Command Q) and open it
   again. Start a new Code session in the `Reels` folder and type
   `set me up`. The kit includes video tools for editing your footage.
   The first time Palmier Pro opens it shows a sign-in screen: click
   Skip. An account is only needed for Palmier's paid AI extras, which
   the kit never uses unless you ask.
   Claude asks whether you already have a reels folder or brand notes,
   then about your page (handle, what you do, your goal, pages you look
   up to), reads your public profile, works out which of
   your reels worked and why, scores your profile with the fix worth the
   most, learns your voice and look, then asks what you want first: reel
   ideas, a reel from your footage, or reels cut from a long video, podcast
   or article you have.

If Claude says it may not read or change files in the `Reels` folder,
your Claude settings limit which folders it can use. Move the `Reels`
folder into a folder where Claude already works for you, open it there
and paste the message again.

Got the kit as a zip file instead? Double-click it, choose the `Reels`
folder that appears in step 3, and type `install` in step 4.

## Updates

The kit keeps itself up to date. Each time you start a session it looks
for a newer version and takes it, which replaces only the kit's own files,
never yours, and Claude tells you in one line what changed. To stop that,
tell Claude "no automatic updates".

Have a copy from before version 16? Paste the message from step 4 of
"Install" once in your `Reels` folder. After that it updates itself.

## Already make reels with Claude?

Keep your current folder exactly as it is, and don't copy these files into
it: the kit lives in its own `Reels` folder. During `set me up`, Claude
first asks whether you already make reels with Claude or have brand notes,
and where: a folder on your Mac, a Claude chat project, or both.

- A chat project: Claude gives you a short message to paste there, and you
  paste the reply back.
- A folder: type its name, or drop it on the message box (that only
  tells Claude where it is; the folder stays put). Click Allow when
  Claude asks to read it.
  Claude reads your notes, scripts and finished reels, plus what you told
  Claude in past chats in that folder and what it saved about you, so the
  corrections you already gave carry over.
- Brand notes as files: drop them into `setup/brand`.

Then Claude asks only what is still open. You can answer, or paste a short
message into a Claude chat in your usual folder and let the Claude that
knows you answer (click Allow when it asks to write into `Reels`). Claude
changes nothing in your usual folder without asking you first, and if you
keep working there too, it picks up what is new.

You can keep the way you edit now and use the kit for the rest: ideas from
what is working on pages like yours, hooks, scripts in your voice and post
captions. Claude asks once which editor makes your reels, yours or the
kit's, and uses only that one on a reel, because two editors on the same
reel undo each other's work. You can switch any time.

Leave your old folder where it is instead of moving it into the `Reels`
folder. If it does end up inside, Claude finds it, reads it as notes and
keeps using the editor you chose.

## Every day

Open the Claude app, click **Code**, start a new session in the `Reels`
folder. Claude tells you what is next in your plan. Or say what you want,
for example "make a reel from today's footage" or "give me ideas for next
week". Claude shows you the edit plan first and waits for your yes. You post
the reel yourself.

When you don't like something, say so. Claude fixes it and, if it should
apply to every reel, saves it so you never have to repeat it. Your details
live in files in the `Reels` folder (`profile.md`, `voice.md`, `design.md`,
`ideas.md`), which kit updates never touch. One `Reels` folder is one
Instagram page: for a second page or a test, install the kit again in a
new folder.

## Good to know

- Out of the box the kit uses free tools only, only reads public Instagram
  pages and never posts, likes, follows or messages. You can change any of
  that by asking, for example to pull footage from Dropbox or add a paid AI
  video tool. Claude tells you the cost first.
- If you prefer Terminal: run `bash setup.sh` inside the `Reels` folder, then
  start `claude` there. `bash setup.sh --check` checks everything anytime.
