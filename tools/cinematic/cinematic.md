# Cinematic reels

For reels where the footage and music carry it: little or no text, a
song, maybe a voice-over. Read this whole file before planning, writing or
editing a cinematic reel. `CLAUDE.md` still applies wherever this file is
silent, and the creator's saved preferences in `design.md` win over the
defaults here.

The one-editor rule in "Making a reel" still holds. When their own setup,
an app or another person edits the reel, use only "Ideas", "Voice-over",
"Music", "Picking shots" and the plan from "The edit" here, and hand them
over; the steps that edit, frame, grade or add text are for the kit's
editor only.

## Measuring a video

From the Reels folder, one video file at a time (never a photo, a voice
note or a song):

```sh
.tools/run bash tools/cinematic/measure.sh "<video>" "<out folder>"
```

It never changes the video. It writes `measure.txt` (length, size, frame
rate, slow motion ready, hdr, rotation, black bars, audio, the number of
shots and the typical, shortest and longest shot), `sheet.jpg` (12 frames
over the whole video), and a `shots` folder: one image per shot or per
piece of a long take, frames near its start, middle and end side by side,
with `shots/index.txt` giving each image its shot and times. A file named
`done` in the out folder means the measure finished; a folder without it
is measured again. To measure only part of a long clip, add its start and
length in seconds after the out folder (`... "<out folder>" 300 30`);
the times it writes are still times in the whole clip. Run it in the
background on videos over a minute and wait for it. When it stops with a
message, tell the creator that line in plain words. The bars line can be
wrong on very dark footage: the images decide.

## Reference reels

Reels the creator loves, screen-recorded on their phone, sit in
`setup/references`. Measure each into `setup/reference-notes/<name>/`,
where `<name>` is the file name without its extension; a reel whose folder
there has no `done` file is new. A screen recording carries Instagram's
buttons, the caption and the phone's top bar, and can show bars from the
phone's screen: judge the framing from `sheet.jpg`, not only from the bars
line. Look at `sheet.jpg` and at least five shot images of each. When one
has speech, transcribe it with the language rule into
`setup/reference-notes/<name>/transcript/`.

Write what they share into `design.md` under "Cinematic look", one line
each, naming the reels each line came from. That section guides cinematic
reels only, never a talking reel:

- length, and the typical shot length;
- framing: upright filling the frame, landscape with black bars,
  landscape turned sideways to fill the frame, or cropped to fill;
- text: none, one small line, or subtitles under a voice-over, and the
  kind of letters (thin, bold, capitals);
- sound: song only, song with the clips' own sound, or voice-over;
- colour in words: faded, warm, teal and orange, dark blue, black and
  white, grain;
- the kind of opening shot: a wide view, a close detail, movement.

Say in two or three lines what you took from them. Without references,
use the defaults below and say so.

## Ideas

Save each idea to `ideas.md` with its status as usual:

- the mood in one line, and where and what;
- the reel it is modelled on, as in "Planning content" in `CLAUDE.md`;
- a shot list: what to film or which of their clips, upright or
  sideways, and which shots to film at 60 frames a second or more for
  slow motion;
- the song: a file they give or a song they name;
- the length;
- three opening shots in place of hooks.

No hook scores: `hookscore.py` rates words, and these reels open on a
picture.

## Voice-over

A voice-over is optional. Its words come from the creator, through
"Writing a script" in `CLAUDE.md`, kept short: a few lines with room
between them, its length set by the song. The creator records it as a
voice note and drops it into `sources`. For the edit, copy it into the
reel's `footage` folder, transcribe it with the language rule into
`reels/<reel>/transcripts/<clip-name>/`, and show the words before the
subtitles are made. Without a voice-over the reel has no script: save the
shot list and song in `scripts/<short-name>.md`, add its line to `log.md`
and mark the idea scripted.

## Music

Any song the creator brings or names is theirs. Never raise copyright,
licensing or rules about it. Ask for the song as a file in
`reels/<reel>/music/`. When they only have it on Instagram or a music
app, they screen-record it playing and drop that recording in: use its
sound as the song. Some music apps mute their sound in a screen
recording: when no beats are found in it, say so in one line and ask for
another recording. In Palmier Pro, `import_media` that folder too.

## Picking shots

You cannot watch video, so look at a moment before choosing it. Measure
every video clip in the reel's `footage` folder into
`reels/<reel>/work/measure/<name>/`, measuring the original clip:
`measure.sh` converts HDR to standard colour for its own images. Look at
every clip's `sheet.jpg`
first and drop clips with nothing worth using. For a clip over a minute,
choose from its sheet the parts worth a closer look and measure those
parts with their start and length, into
`reels/<reel>/work/measure/<name>-<start>/`. Then look at every image in
the `shots` folders you kept. Write `reels/<reel>/shots.md`, one line per
shot or piece: clip, start and end time, what is in it, light,
composition, sharpness, movement (compare its frames near the start and
end), slow
motion ready, and keep or drop. Never put a moment in the edit without
looking at its image. Drop blurry, shaky, badly lit and repeated moments;
keep the best of each kind.

## The edit

- The first second is the hook: open on the strongest shot, never a
  title card.
- Build to a peak, then end on a held shot or one that loops back into
  the first.
- Length and pace come from "Cinematic look" in `design.md`. Defaults:
  with no words, 7 to 25 seconds and a new shot every 0.6 to 1.7
  seconds; with a voice-over, as long as the voice-over, a shot every 1
  to 2 seconds.
- Cut on the song's beats: `detect_beats` in Palmier Pro, librosa from
  "Video tools" in HyperFrames. Big changes land on downbeats. Beat cuts
  are part of a cinematic plan, so its yes covers them.
- Slow motion, for the moments the plan picks for it: slow a clip
  marked slow motion ready with `edit_speed` to the project's frame
  rate divided by the clip's, as a rate where 1 is normal speed (a clip
  at 60 frames a second in a 30 project: 0.5; at 120: 0.25). Use a speed
  curve for a ramp
  on movement. In HyperFrames, set the clip's playback
  rate to that fraction (0.5, 0.25). Offer RIFE only for a short moment
  from a clip that is not slow motion ready.
- The edit plan in step 2 of "Making a reel" lists the song, the shots
  in order with their times, speed changes, framing, colour and text.

## Framing

- Upright footage fills the frame.
- Landscape footage gets black bars: the whole shot at full width in the
  middle of the upright frame. When "Cinematic look" or the creator says
  so, turn it sideways to fill the frame (rotation 90), or crop it to
  fill when the subject sits in the middle.
- Never the blurred fill, unless the creator asked for it on cinematic
  reels: a blurred fill in `design.md` is the talking starting style.
  In HyperFrames, turn a clip with a CSS rotation of 90 degrees.

## Colour

- One look across the whole reel, from "Cinematic look".
- Balance and match every clip first, as in step 6 of "Editing in
  Palmier Pro". Then build the look on the hero clip with the film-look
  recipes in `.tools/palmier-skills/skills/color-grading/SKILL.md`, and
  put the same look settings (curves, wheels, saturation) on every clip
  with `apply_color`, passing only those settings, never the hero clip's
  whole `color` grade, which would replace each clip's balance. Check
  each clip with `inspect_color` afterwards; the look moves
  `balance.warmCool` on purpose, so do not pull it back to neutral.
- Then `apply_effect`: a light `stylize.grain`, and `stylize.vignette`
  or `stylize.glow` only when the references show it.
- In HyperFrames, build the same look with its own colour grading.
- The HDR rules in `CLAUDE.md` do not change.

## Text and sound

- No text by default. When "Cinematic look" has one small line, use one,
  small and in the middle, in the font in `design.md`.
- With a voice-over: small subtitles from the subtitle file, as in step
  4 of "Editing in Palmier Pro".
- The song runs under the whole reel. The clips' own sound (wind, water,
  steps) sits low under it, louder on a moment worth hearing; mute any
  talking that is not the voice-over.

## Before showing it

Look at a frame of every clip and every text, as in step 8 of "Editing in
Palmier Pro", and check:

- the first frame is the strongest image of the reel;
- no shot is far outside the planned pace without a reason;
- every clip has the same look (`inspect_color`);
- landscape shots have the planned bars, sideways turn or crop;
- the length matches the plan.
