// Krohnkite only focuses or swaps within one screen; at the edge its directional keys do nothing.
// These keys hand over to Krohnkite while there is a window on that side, and otherwise cross
// to the neighbouring screen: focus its topmost window, or send the window there.
const DIRS = { Left: [-1, 0], Up: [0, -1], Right: [1, 0], Down: [0, 1] };

function onCurrentDesktop(win) {
    return win.onAllDesktops || win.desktops.indexOf(workspace.currentDesktop) !== -1;
}

function candidates(output) {
    return workspace.stackingOrder.filter(function (w) {
        return w.normalWindow && !w.minimized && w.output === output && onCurrentDesktop(w);
    });
}

// Is b on side [dx, dy] of a, overlapping it across that axis?
function beside(a, b, d) {
    const slack = 2;
    if (d[0] !== 0) {
        const ahead = d[0] < 0 ? b.x + b.width <= a.x + slack : b.x >= a.x + a.width - slack;
        return ahead && b.y < a.y + a.height && a.y < b.y + b.height;
    }
    const ahead = d[1] < 0 ? b.y + b.height <= a.y + slack : b.y >= a.y + a.height - slack;
    return ahead && b.x < a.x + a.width && a.x < b.x + b.width;
}

function screenBeside(output, d) {
    const a = output.geometry;
    let best = null, bestDist = Infinity;
    workspace.screens.forEach(function (s) {
        if (s === output || !beside(a, s.geometry, d)) return;
        const g = s.geometry;
        const dist = Math.abs(g.x + g.width / 2 - a.x - a.width / 2) + Math.abs(g.y + g.height / 2 - a.y - a.height / 2);
        if (dist < bestDist) { best = s; bestDist = dist; }
    });
    return best;
}

function krohnkite(action) {
    callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component",
             "invokeShortcut", "Krohnkite" + action);
}

function go(dir, move) {
    const win = workspace.activeWindow;
    const d = DIRS[dir];
    const output = win ? win.output : workspace.activeScreen;
    const neighbour = win && candidates(output).some(function (w) {
        return w !== win && beside(win.frameGeometry, w.frameGeometry, d);
    });
    if (neighbour) return krohnkite((move ? "Shift" : "Focus") + dir);
    const screen = screenBeside(output, d);
    if (!screen) return;
    if (move) {
        if (win && win.moveableAcrossScreens) workspace.sendClientToScreen(win, screen);
        return;
    }
    const others = candidates(screen);
    if (others.length) workspace.activeWindow = others[others.length - 1];
}

Object.keys(DIRS).forEach(function (dir) {
    registerShortcut("NookFocus" + dir, "Nook: focus window " + dir.toLowerCase(),
                     "Meta+" + dir, function () { go(dir, false); });
    registerShortcut("NookMove" + dir, "Nook: move window " + dir.toLowerCase(),
                     "Meta+Alt+" + dir, function () { go(dir, true); });
});
