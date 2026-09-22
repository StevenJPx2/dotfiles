// Service worker for the Browser Harness Tab Groups extension.
//
// Two jobs:
//  1. Auto-group: any tab whose title gains the browser-harness 🐴 marker and
//     is not yet in a group is moved into the default "Agents" group. This
//     needs no bridge, so MCP-driven sessions get grouped for free.
//  2. Per-agent groups: `bhGroupByTitle(needle, title, color)` is called over
//     CDP (Runtime.evaluate on this worker) by the `browser-group` CLI. The
//     caller temporarily sets the tab title to a nonce so the tab can be
//     matched without a CDP-target → tab-id mapping, which Chrome does not
//     expose.

const MARKER = "\u{1F434}";
const DEFAULT_GROUP = { title: "Agents", color: "purple" };
const NONE = chrome.tabGroups.TAB_GROUP_ID_NONE;

async function findGroup(windowId, title) {
  const groups = await chrome.tabGroups.query({ windowId, title });

  return groups[0] ?? null;
}

async function groupTab(tab, { title, color }) {
  const existing = await findGroup(tab.windowId, title);
  if (existing && tab.groupId === existing.id) return existing.id;

  const groupId = existing
    ? await chrome.tabs.group({ tabIds: tab.id, groupId: existing.id })
    : await chrome.tabs.group({ tabIds: tab.id });

  if (!existing) {
    await chrome.tabGroups.update(groupId, { title, color, collapsed: false });
  }

  return groupId;
}

chrome.tabs.onUpdated.addListener(async (_tabId, change, tab) => {
  if (!change.title || !change.title.startsWith(MARKER)) return;
  if (tab.groupId !== NONE || tab.pinned) return;

  try {
    await groupTab(tab, DEFAULT_GROUP);
  } catch (err) {
    // Popup/app windows report "Grouping is not supported by tabs in this window".
    console.warn("[bh-tab-groups] auto-group skipped:", err?.message ?? err);
  }
});

globalThis.bhGroupByTitle = async function bhGroupByTitle(needle, title, color = "purple") {
  const tabs = await chrome.tabs.query({});
  const tab = tabs.find((t) => (t.title || "").includes(needle));
  if (!tab) throw new Error(`no tab whose title contains ${needle}`);

  const groupId = await groupTab(tab, { title, color });

  return { tabId: tab.id, windowId: tab.windowId, groupId, title };
};

globalThis.bhListGroups = async function bhListGroups() {
  const groups = await chrome.tabGroups.query({});
  const out = [];

  for (const g of groups) {
    const tabs = await chrome.tabs.query({ groupId: g.id });
    out.push({ id: g.id, title: g.title, color: g.color, windowId: g.windowId, tabs: tabs.length });
  }

  return out;
};
