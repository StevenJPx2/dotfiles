---
name: imgup
description: Upload images to hosting services (Imgur, imgbb, Gyazo, catbox, and 30+ others) via the imgup CLI tool and return hosted URLs. Use when user wants to upload an image, share an image online, get a hosted image URL, or upload screenshots/photos to an image host.
---

# imgup

CLI tool to upload images to 30+ hosting services and return a hosted URL.

## Quick start

```bash
# Upload to Imgur (default, no key needed)
imgup screenshot.png

# Upload to imgbb (requires IMGBB_KEY)
imgup -H imgbb photo.jpg

# Get a markdown-formatted link
imgup -f markdown image.png

# Upload multiple images
imgup img1.png img2.png img3.png
```

## Install

```bash
uv tool install images-upload-cli   # PyPI (easiest)
yay -S imgup-bin                    # AUR (Arch Linux)
```

## Common hostings

| Host | Key needed | Notes |
|------|-----------|-------|
| `imgur` | No (optional) | Default; set `IMGUR_CLIENT_ID` for higher rate limits |
| `catbox` | No | Permanent, no account needed |
| `imgbb` | Yes | `IMGBB_KEY` |
| `gyazo` | Yes | `GYAZO_TOKEN` |
| `pixeldrain` | Yes | `PIXELDRAIN_KEY` |

Full list: beeimg, catbox, fastpic, gofile, imgbox, kappa, pixhost, sxcu, imgur, cloudinary, filepost, freeimage, gyazo, imageban, imagekit, imgbb, imgchest, imghippo, imglink, lensdump, pixeldrain, pixvid, postimages, ptpimg, thumbsnap, tixte, uplio, uploadcare, vgy, zpic.

## Output formats

```bash
imgup -f plain     # https://i.imgur.com/abc123.png  (default)
imgup -f markdown  # ![](https://i.imgur.com/abc123.png)
imgup -f html      # <img src="https://i.imgur.com/abc123.png">
imgup -f bbcode    # [img]https://i.imgur.com/abc123.png[/img]
```

## API keys / env setup

Keys go in a `.env` file or as environment variables:

- **macOS**: `~/Library/Application Support/imgup/.env`
- **Linux**: `~/.config/imgup/.env`

```bash
# Example .env
IMGUR_CLIENT_ID=your_client_id
IMGBB_KEY=your_key
GYAZO_TOKEN=your_token
```

Or pass a custom env file per-run:

```bash
imgup --env-file /path/to/.env image.png
```

## Workflow: upload and use URL

1. Run `imgup image.png` — the URL is printed to stdout and auto-copied to clipboard
2. Paste the URL wherever needed
3. Use `--no-clipboard` to skip clipboard copy
4. Use `--notify` for a desktop notification on completion

## Options reference

| Flag | Default | Description |
|------|---------|-------------|
| `-H, --hosting` | `imgur` | Hosting service |
| `-f, --format` | `plain` | Output format: plain, markdown, html, bbcode |
| `-t, --thumbnail` | off | Generate captioned thumbnail links |
| `-n, --notify` | off | Desktop notification on completion |
| `--no-clipboard` | off | Disable auto-copy to clipboard |
| `-j, --jobs` | 4 | Max concurrent uploads |
| `-v / -vv` | off | Verbose / debug output |
