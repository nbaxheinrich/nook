// The Nook line icons (24px grid, 1.75 stroke, square caps, mitre joins), one per category,
// as SVG data URLs inked in a single hue. Paths from the design system's Launcher.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property var paths: ({
        terminal: '<rect x="3" y="4" width="18" height="16"/><polyline points="7,9 10,12 7,15"/><line x1="12" y1="15" x2="17" y2="15"/>',
        folder:   '<path d="M3 5h6l2 2h10v12H3z"/><line x1="3" y1="10" x2="21" y2="10"/>',
        globe:    '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><line x1="3" y1="12" x2="21" y2="12"/>',
        code:     '<polyline points="8,7 3,12 8,17"/><polyline points="16,7 21,12 16,17"/><line x1="14" y1="4" x2="10" y2="20"/>',
        music:    '<path d="M9 18V5l11-2v13"/><rect x="4" y="15.5" width="5" height="5"/><rect x="15" y="13.5" width="5" height="5"/>',
        chat:     '<path d="M3 4h18v12H10l-5 4v-4H3z"/><path d="M7 8.5h10M7 12h6"/>',
        shield:   '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><polyline points="8.5,12 11,14.5 15.5,10"/>',
        settings: '<line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/><rect x="6" y="3.5" width="4" height="5" fill="currentColor" stroke="none"/><rect x="14" y="9.5" width="4" height="5" fill="currentColor" stroke="none"/><rect x="9" y="15.5" width="4" height="5" fill="currentColor" stroke="none"/>',
        clock:    '<circle cx="12" cy="12" r="9"/><polyline points="12,7 12,12 16,14"/>',
        game:     '<rect x="2" y="7" width="20" height="11"/><line x1="7" y1="10" x2="7" y2="15"/><line x1="4.5" y1="12.5" x2="9.5" y2="12.5"/><rect x="15" y="10" width="2" height="2" fill="currentColor" stroke="none"/><rect x="17" y="13" width="2" height="2" fill="currentColor" stroke="none"/>',
        user:     '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.5 3.5-7 8-7s8 2.5 8 7"/>',
        power:    '<path d="M6.3 6.8a8 8 0 1 0 11.4 0"/><line x1="12" y1="2.5" x2="12" y2="11"/>',
        app:      '<rect x="4" y="4" width="16" height="16"/><rect x="9" y="9" width="6" height="6" fill="currentColor" stroke="none"/>'
    })

    function url(name, hue) {
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" '
                  + 'stroke="currentColor" stroke-width="1.75" stroke-linecap="square" stroke-linejoin="miter" color="'
                  + hue + '">' + (paths[name] ?? paths.app) + '</svg>';
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg.replace(/currentColor/g, hue));
    }
}
