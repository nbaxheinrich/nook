// Shared shell state: what is open. The bar, the launcher, the control center and IPC all
// read and write this. Only one popup at a time.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    property bool launcherOpen: false
    property bool controlOpen: false
    property string controlTab: "audio"          // audio · net · bt · apps

    function toggleLauncher() { controlOpen = false; launcherOpen = !launcherOpen }
    function openControl(tab) {
        launcherOpen = false;
        if (controlOpen && controlTab === tab) { controlOpen = false; return; }
        controlTab = tab;
        controlOpen = true;
    }
}
