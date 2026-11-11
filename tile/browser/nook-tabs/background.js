// nook tabs: answers three questions from the local nook-tabs helper (native messaging):
//   list                 → every tab's id, window, title, url
//   activate {tab: id}   → show that tab and focus its window
//   close    {tab: id}   → close it
// Nothing else: no page access, no scripts, no opening URLs. The helper is the only thing it
// talks to, and the browser only starts helpers registered for this extension's id.
const HOST = "nook.tabs";
let port = null;

function connect() {
  if (port) return;
  port = chrome.runtime.connectNative(HOST);
  port.onMessage.addListener(answer);
  port.onDisconnect.addListener(() => {
    void chrome.runtime.lastError;   // helper missing or quit: try again later
    port = null;
    setTimeout(connect, 30000);
  });
}

async function answer(m) {
  const reply = r => port && port.postMessage({ id: m.id, ...r });
  try {
    if (m.cmd === "list") {
      const tabs = await chrome.tabs.query({});
      reply({ ok: true, tabs: tabs.map(t => ({
        id: t.id, window: t.windowId, title: t.title ?? "", url: t.url ?? "",
        active: t.active, audible: !!t.audible })) });
    } else if (m.cmd === "activate" && Number.isInteger(m.tab)) {
      const t = await chrome.tabs.update(m.tab, { active: true });
      await chrome.windows.update(t.windowId, { focused: true });
      reply({ ok: true, title: t.title ?? "" });
    } else if (m.cmd === "close" && Number.isInteger(m.tab)) {
      await chrome.tabs.remove(m.tab);
      reply({ ok: true });
    } else {
      reply({ ok: false, error: "unknown request" });
    }
  } catch (e) {
    reply({ ok: false, error: String(e?.message ?? e) });
  }
}

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
connect();
