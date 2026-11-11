// What the shell shows, picked live in the control center's `nook` tab (or over IPC) and kept in
// ~/.config/nook/shell.json. Only what's switched OFF is stored, so new parts show up by default.
//   qs -c nook ipc call nook toggle|on|off bar.cpu        qs -c nook ipc call nook list
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // every part that can be switched off: id, name in the list, what it is
    readonly property var bar: [
        { id: "bar.start",      name: "λ nook",     note: "menu button" },
        { id: "bar.workspaces", name: "workspaces", note: "1–9 dots" },
        { id: "bar.title",      name: "window",     note: "[ app — title ]" },
        { id: "bar.clock",      name: "clock",      note: "kb, battery; opens control" },
        { id: "bar.cpu",        name: "cpu · ram",  note: "sparkline" },
        { id: "bar.power",      name: "power",      note: "⏻" }
    ]
    readonly property var widgets: [
        { id: "widget.time",    name: "TIME // LOCAL",  note: "block clock" },
        { id: "widget.sys",     name: "SYS // LIVE",    note: "cpu ram disk gpu net" },
        { id: "widget.media",   name: "NOW // PLAYING", note: "while a player runs" },
        { id: "widget.weather", name: "WX // OUTSIDE",  note: "wttr.in" },
        { id: "widget.srv",     name: "SRV // HOMELAB", note: "needs hosts" },
        { id: "widget.cal",     name: "CAL // NEXT",    note: "needs CalDAV" },
        { id: "widget.proc",    name: "PROC // TOP",    note: "click to kill" }
    ]
    readonly property var desk: [
        { id: "desk.banner",     name: "NOOK banner", note: "on the wallpaper" },
        { id: "desk.grid",       name: "dot grid",    note: "and scanlines" },
        { id: "desk.cheatsheet", name: "cheatsheet",  note: "SUPER /" }
    ]
    readonly property var all: bar.concat(widgets, desk)

    readonly property list<string> hidden: adapter.hidden
    function shown(id) { return root.hidden.indexOf(id) < 0 }
    function set(id, on) {
        if (on === root.shown(id)) return;
        adapter.hidden = on ? root.hidden.filter(x => x !== id) : root.hidden.concat([id]);
    }
    function toggle(id) { root.set(id, !root.shown(id)) }

    IpcHandler {
        target: "nook"
        function toggle(id: string): void { root.toggle(id) }
        function on(id: string): void { root.set(id, true) }
        function off(id: string): void { root.set(id, false) }
        function list(): string { return root.all.map(p => (root.shown(p.id) ? "on   " : "off  ") + p.id).join("\n") }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/nook/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: adapter
            property list<string> hidden: []
        }
    }
}
