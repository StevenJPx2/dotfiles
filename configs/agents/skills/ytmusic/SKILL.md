---
name: ytmusic
description: >-
  Use for YouTube Music or YouTube playlists and library work: create or edit a playlist from a list of songs (worship sets, setlists), search songs, add or remove tracks, read the user's library. Drives the ytmusicapi Python library, with auth taken from the user's logged-in Chrome through the ytm-auth helper.
---

# YouTube Music (ytmusicapi)

Use [ytmusicapi](https://github.com/sigma67/ytmusicapi) instead of clicking
through the YouTube UI. Docs: context7 `/websites/ytmusicapi_readthedocs_io`,
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

## 2. Authenticate

Only playlist and library writes need auth. Get it from the user's Chrome:

```bash
browser-launch status          # the CDP port must be live; see the browser-harness skill
browser-profile --list         # find the profile signed in to the right YouTube account
ytm-auth "Profile 1" "$TMPDIR/opencode/ytm/browser.json"
```

`ytm-auth` writes `browser.json` (mode 0600) without printing the cookies,
then prints the account name. If the daemon already has a music.youtube.com
tab, the helper reuses it and ignores the profile argument. Otherwise it opens
one in that profile. Either way, check the printed account is the one the
user expects. Ask before reading cookies, and ask which profile to use: the
harness's default profile is a work account.

`browser.json` holds live session tokens. Never print it or cat it, keep it
out of git, and delete it at the end with `rm -P`.

If you build the file by hand, it needs an `Authorization: SAPISIDHASH …`
header. Without that header ytmusicapi assumes OAuth and fails with
`oauth_credentials not provided`. See `ytmusicapi.helpers.get_authorization`.

## 3. Write

```python
yt = YTMusic("browser.json")
pid = yt.create_playlist(title, description, privacy_status="UNLISTED", video_ids=ids)
yt.add_playlist_items(pid, ids)                      # append
yt.remove_playlist_items(pid, yt.get_playlist(pid)["tracks"][i:j])
yt.edit_playlist(pid, title=..., privacyStatus=...)
```

- Privacy is `PRIVATE` (the default), `UNLISTED` or `PUBLIC`. Ask which one.
  Unlisted suits a set shared with a team.
- A playlist has no sections. Put the set order in the description, for
  example `Pre-worship: … | Worship: … | Offertory: …`, and add the tracks in
  that order.
- `create_playlist` returns the ID as a string; on error it returns the full
  response dict instead. Playlist IDs can be short (for example `PLAGl_Bf7AwKE`).

## 4. Verify

Right after creation, `get_playlist(pid)` can fail with
`KeyError: 'contents'`. Verify on the page instead, in the same Chrome tab:

```bash
BU_NAME=opencode-browser browser-harness <<'PY'
goto_url("https://music.youtube.com/playlist?list=<pid>")
wait_for_load(); import time; time.sleep(3)
print(js("JSON.stringify([...document.querySelectorAll('ytmusic-responsive-list-item-renderer')].map(r=>r.querySelector('.title')?.textContent.trim()))"))
print(js("[...document.querySelectorAll('ytmusic-responsive-header-renderer span')].map(s=>s.textContent.trim()).find(t=>/^(Unlisted|Private|Public)$/.test(t))"))
PY
```

Report the link `https://music.youtube.com/playlist?list=<pid>` along with a
table of the tracks, and delete `browser.json`.
