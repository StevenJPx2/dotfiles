---
name: qwen-mm-plugins
description: Use Qwen-MM-Plugins for multimodal work involving images, video, audio, documents, 3D files, visual inspection, media search, or media generation.
---

# Qwen-MM-Plugins

The OpenCode plugin registers the upstream Qwen-MM-Plugins MCP servers. `core`
is enabled by default. Enable more capabilities before restarting OpenCode with
`QWEN_MM_CAPABILITIES=core,api,search` or `QWEN_MM_CAPABILITIES=all`.

Use the capability that matches the task:

- `core`: read images, video, documents, code, data, and 3D files; crop or annotate images; extract video frames.
- `api`: use DashScope models for vision chat, OCR, grounding, ASR, timestamped audio-video analysis, and segmentation.
- `search`: use Serper for web search, page extraction, and reverse-image search.
- `video-memory`: build and query hierarchical memory for videos longer than 30 minutes.
- `video-edit`: generate image, video, and audio assets through the MCP tools; editing of supplied footage is the upstream `video-edit` skill workflow.
- `blender`: drive a running Blender instance for 3D modeling and rendering.
- `freecad`: drive a running FreeCAD instance for parametric CAD and FEM work.

`edu-agent` (Chinese math/science tutorial-video generation) is a skill-only capability with no MCP server, so it is not part of `QWEN_MM_CAPABILITIES`; install it manually by copying `src/capabilities/edu-agent/skill` from the upstream repo.

Prefer `core` for local files. For videos and audio, inspect metadata first;
for videos longer than 30 minutes, use `video-memory` before frame-level
inspection. Use `api` only when external model understanding is needed, and
`search` when an identity or fact must be confirmed externally.

The MCP servers are installed on first use through `uvx`, so `uv` must be on
`PATH`. API capabilities read `DASHSCOPE_API_KEY` or `SERPER_API_KEY` from the
environment when exported; otherwise the upstream configuration file at
`~/.qwen-mm-plugins/config` is used as the fallback.

For the complete tool schemas and capability workflows, see:
https://github.com/QwenLM/Qwen-MM-Plugins
