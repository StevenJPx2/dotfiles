---
name: ytmusic
description: >-
  Use for YouTube Music or YouTube playlists and library work: create or edit a playlist from a list of songs (worship sets, setlists), search songs, add or remove tracks, read the user's library. Resolves songs with the ytmusicapi Python library and makes playlist and library changes in the user's signed-in Yab browser.
---

# YouTube Music (ytmusicapi)

Use [ytmusicapi](https://github.com/sigma67/ytmusicapi) to find songs instead
of searching through the YouTube UI. Docs: context7 `/websites/ytmusicapi_readthedocs_io`,
or https://ytmusicapi.readthedocs.io/en/stable/. Run it with no install step:

```bash
uv run --with ytmusicapi python - <<'PY'
from ytmusicapi import YTMusic
...
PY
```

Work in a temp directory (`$TMPDIR/opencode/ytm`), not in a project.

## 1. Resolve songs (no auth needed)

```python
yt = YTMusic()
for r in yt.search("What a Beautiful Name", filter="songs", limit=5)[:5]:
    print(r["videoId"], r["title"], [a["name"] for a in r["artists"]], r.get("duration"))
yt.get_song(video_id)["videoDetails"]  # title and author for a link the user gave
```

- Take the video ID from any link the user gave (`watch?v=<id>`) as is.
- Song titles are ambiguous. "Our Father" could be Don Moen, Bethel or
  Hillsong. Show the top hits and ask with the question tool, putting the
  most likely version first. Prefer original studio or live versions over
  covers, karaoke, piano or instrumental versions.

## 2. Pick the account

Playlist and library changes happen in YouTube Music itself, in Yab (see the
browsers skill), where the user is already signed in. Never read cookies or
build a ytmusicapi `browser.json`: Yab doesn't export session tokens.

```js
const y = tools["yab-browser"];
await y.spaces({ site: "music.youtube.com" });   // which spaces are signed in, as whom
```

Ask which account to use when more than one space is signed in (one is a work
account), then pass that `space` to `open`. Check the avatar menu shows the
expected account before changing anything.

## 3. Write

Drive YouTube Music's own UI with `run`, so a whole playlist is one call:

1. Open `https://music.youtube.com/library/playlists`, click **New playlist**,
   fill the title and description, pick the privacy and create it. Note the
   `list=` ID from the URL it lands on.
2. For each video ID, in order, open
   `https://music.youtube.com/watch?v=<id>`, open the song's **⋮** menu (or the
   player bar's), choose **Save to playlist** and pick the new playlist. Check
   the "Saved to …" toast before moving on; on a miss, snapshot and retry that
   one song rather than the whole list.
3. To remove or reorder, use the playlist page's own row menus and drag
   handles. Removals are deletions: confirm with the user first.

- Privacy is Private (the default), Unlisted or Public. Ask which one.
  Unlisted suits a set shared with a team.
- A playlist has no sections. Put the set order in the description, for
  example `Pre-worship: … | Worship: … | Offertory: …`, and add the tracks in
  that order.
- Find buttons by their labels from the snapshot (`t.find('Save to playlist')`);
  YouTube's markup changes too often for fixed selectors.

## 4. Verify

Open `https://music.youtube.com/playlist?list=<pid>` in the same space and
read it with `text` (or `snapshot`). Check the track titles, their order and
the privacy label against what you meant to add.

Report the link `https://music.youtube.com/playlist?list=<pid>` with a table
of the tracks, then `close` the agent tabs.
