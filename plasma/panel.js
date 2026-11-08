// Nook taskbar: one floating, auto-hiding bar along the bottom of the primary screen.
//   left   λ start button + pinned/running apps
//   centre clock (two flexible spacers keep it centred on the screen)
//   right  tray
// One bar rather than separate islands: an auto-hidden panel only comes back when the mouse
// pushes against the screen edge right under it, so a full-width bar reacts anywhere along it.
// Run through org.kde.PlasmaShell.evaluateScript; apply.sh fills in __LAUNCHERS__.
// Replaces every existing panel (apply.sh backs up the old layout first).

panels().forEach(function (p) { p.remove(); });

var bar = new Panel();
bar.screen = 0;            // new panels open on the screen under the mouse; 0 is the primary one
bar.location = "bottom";
bar.height = 44;
bar.floating = true;
bar.lengthMode = "fill";
bar.hiding = "autohide";   // slides away; push the mouse to the bottom edge to bring it back

// ── left: start + apps ──
var kickoff = bar.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "nook-start");  // filled, so it reads as the start button
kickoff.writeConfig("menuLabel", "");
kickoff.writeConfig("favoritesDisplay", 1); // list, not grid
kickoff.writeConfig("applicationsDisplay", 1);
kickoff.writeConfig("compactMode", true);

bar.addWidget("org.kde.plasma.marginsseparator");  // a little extra room between start and the apps

var tasks = bar.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", "__LAUNCHERS__");
tasks.writeConfig("indicateAudioStreams", true);
tasks.writeConfig("iconSpacing", 1);
tasks.writeConfig("fill", false);

// ── centre: clock (the Nook clock in its compact, colourful panel form) ──
bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.nook.clock");
bar.addWidget("org.kde.plasma.panelspacer");

// ── right: tray ──
var tray = bar.addWidget("org.kde.plasma.systemtray");
tray.currentConfigGroup = ["General"];
tray.writeConfig("scaleIconsToFit", true);  // tray icons as big as the app icons on the left
tray.writeConfig("iconSpacing", 1);
