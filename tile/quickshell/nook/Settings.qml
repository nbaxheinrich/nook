// What the shell shows and how the bar looks, picked live in the control center's `nook` tab (or over IPC) and kept in
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

    // how the bar looks: the modules (pills) and the strip that joins them
    readonly property var pillStyles: [
        { id: "box",     note: "filled, square corners, hairline" },
        { id: "round",   note: "filled capsules" },
        { id: "glass",   note: "see-through, highlight on top" },
        { id: "chip",    note: "solid dark, coloured side bar" },
        { id: "tab",     note: "rises from the screen edge" },
        { id: "neon",    note: "glowing outline tube" },
        { id: "bracket", note: "no fill, [ corner marks ]" },
        { id: "under",   note: "no fill, a neon underline" },
        { id: "text",    note: "nothing, just the glowing text" }
    ]
    readonly property var stripStyles: [
        { id: "strip",    note: "dark strip, hairline on top" },
        { id: "glow",     note: "dark strip, neon line on top" },
        { id: "baseline", note: "no strip, neon line on the edge" },
        { id: "float",    note: "no strip, pills float" }
    ]
    readonly property var barLayouts: [
        { id: "split",  note: "menu + workspaces left, clock right" },
        { id: "center", note: "workspaces in the middle" },
        { id: "clock",  note: "clock in the middle" },
        { id: "island", note: "everything together in the middle" },
        { id: "corner", note: "everything on the left" }
    ]
    readonly property string barLayout: adapter.barLayout
    readonly property string pillStyle: adapter.pillStyle
    readonly property string stripStyle: adapter.stripStyle
    function setStyle(kind, id) {
        const list = kind === "pill" ? pillStyles : kind === "strip" ? stripStyles : kind === "layout" ? barLayouts : [];
        if (!list.some(x => x.id === id)) return false;
        if (kind === "pill") adapter.pillStyle = id; else if (kind === "strip") adapter.stripStyle = id; else adapter.barLayout = id;
        return true;
    }
    function nextStyle(kind) {
        const list = kind === "pill" ? pillStyles : kind === "strip" ? stripStyles : barLayouts;
        const cur = kind === "pill" ? pillStyle : kind === "strip" ? stripStyle : barLayout;
        setStyle(kind, list[(list.findIndex(x => x.id === cur) + 1) % list.length].id);
    }

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
        function list(): string {
            return root.all.map(p => (root.shown(p.id) ? "on   " : "off  ") + p.id).join("\n")
                + "\npill   " + root.pillStyle + "\nstrip  " + root.stripStyle + "\nlayout " + root.barLayout;
        }
        // qs -c nook ipc call nook style pill round · … style strip float
        function style(kind: string, id: string): string {
            return root.setStyle(kind, id) ? kind + " " + id
                : "unknown; pill: " + root.pillStyles.map(x => x.id).join(" ") + " · strip: " + root.stripStyles.map(x => x.id).join(" ")
                  + " · layout: " + root.barLayouts.map(x => x.id).join(" ");
        }
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
            property string pillStyle: "bracket"
            property string stripStyle: "float"
            property string barLayout: "split"
        }
    }
}
