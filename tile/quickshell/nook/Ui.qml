// Shared shell state: what is open. The bar, the launcher and IPC all read and write this.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    property bool launcherOpen: false
    function toggleLauncher() { launcherOpen = !launcherOpen }
}
